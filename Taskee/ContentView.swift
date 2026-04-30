//
//  ContentView.swift
//  Taskee
//
//  Created by Selva Bhuvanesh on 4/25/26.
//

import SwiftUI
import SwiftData
import StoreKit

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

// MARK: - User Avatar Header

struct UserAvatarHeader: View {
    let name: String
    let avatar: String

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(avatarId: avatar, size: 44)

            Text("Hi, \(name)")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
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

    private var children: [FamilyMember] {
        var seen = Set<String>()
        return allMembers.filter { $0.isChild }.filter { seen.insert($0.name).inserted }
    }
    private var pendingChildren: [FamilyMember] {
        allMembers.filter { $0.isChild && !$0.isAccepted }
    }
    @State private var showingAddTask = false
    @State private var showingChildren = false
    @State private var showPendingApprovals = false
    @State private var showOpenOnly = true
    @State private var showCelebration = false
    @State private var celebrationReward: Double = 0
    @State private var showNotificationCenter = false
    @State private var showSubscription = false
    @State private var showRedemptionApprovals = false
    @State private var showRewardsHistory = false
    @State private var showEditProfile = false
    @State private var stickyNote: (message: String, color: Color)?
    @State private var showReminderSent = false
    @State private var reminderSentChildName = ""
    @State private var showShareSheet = false
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Query private var allRedemptions: [RewardRedemption]

    private var pendingRedemptions: [RewardRedemption] {
        allRedemptions.filter { $0.isPending }
    }

    private var activeTasks: [Item] {
        tasks.filter { !$0.isArchived }
    }

    private var myTasks: [Item] {
        activeTasks.filter { $0.assignedTo == authManager.userName || $0.assignedTo.isEmpty || $0.isInReview }
    }

    private var filteredTasks: [Item] {
        showOpenOnly ? myTasks.filter { !$0.isApproved } : myTasks
    }

    private var pendingReviewCount: Int {
        activeTasks.filter { $0.isInReview }.count
    }

    private var pendingActionCount: Int {
        pendingReviewCount + pendingRedemptions.count + pendingChildren.count
    }

    private var groupedTasks: [(key: String, tasks: [Item])] {
        let grouped = Dictionary(grouping: filteredTasks) { $0.dueDateLabel }
        return grouped
            .map { (key: $0.key, tasks: $0.value) }
            .sorted { first, second in
                guard let d1 = first.tasks.first?.targetDate,
                      let d2 = second.tasks.first?.targetDate else { return false }
                return d1 < d2
            }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        UserAvatarHeader(name: authManager.userName, avatar: authManager.avatar)

                        if !children.isEmpty {
                            childrenStrip
                        }
                    }
                    .padding(.top, 8)

                    if subscriptionManager.tier != .pro {
                        tierBanner
                            .padding(.horizontal, 16)
                            .padding(.bottom, 6)
                    }

                    ScrollView {
                        if filteredTasks.isEmpty {
                            emptyState
                        } else {
                            groupListContent
                        }
                    }
                    .refreshable {
                        guard !authManager.familyCode.isEmpty else { return }
                        await cloudKitManager.syncAll(context: modelContext, familyCode: authManager.familyCode) { tasks in
                            for task in tasks {
                                notificationManager.scheduleTaskReminder(taskId: task.id, taskName: task.name, assignedTo: task.assignedTo, dueDate: task.targetDate)
                            }
                        }
                    }

                    addTaskButton
                        .padding(.bottom, 8)
                }

                CelebrationOverlay(
                    isActive: $showCelebration,
                    title: "Task Approved!",
                    subtitle: "Reward credited",
                    rewardAmount: celebrationReward
                )

                if let note = stickyNote {
                    VStack {
                        Spacer()
                        StickyNoteView(message: note.message, color: note.color) {
                            withAnimation { stickyNote = nil }
                        }
                        .padding(.bottom, 80)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .onAppear { scheduleStickyNote(from: parentTips) }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationTitle("\(authManager.userName)'s Tasks")
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
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.orange, in: Capsule())
                            }
                        }

                        if !pendingRedemptions.isEmpty {
                            Button {
                                showRedemptionApprovals = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "gift.fill")
                                        .font(.caption2)
                                    Text("\(pendingRedemptions.count)")
                                }
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.purple, in: Capsule())
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showNotificationCenter = true
                        } label: {
                            Image(systemName: "bell.fill")
                                .font(.subheadline)
                                .overlay(alignment: .topTrailing) {
                                    if pendingActionCount > 0 {
                                        Text("\(pendingActionCount)")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.white)
                                            .frame(minWidth: 14, minHeight: 14)
                                            .background(.red, in: Circle())
                                            .offset(x: 6, y: -6)
                                    }
                                }
                        }

                        Button {
                            showingChildren = true
                        } label: {
                            Image(systemName: "person.2")
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

                        Menu {
                            Text(authManager.userName)
                            if !authManager.email.isEmpty {
                                Text(authManager.email)
                            }
                            Divider()
                            Button {
                                showEditProfile = true
                            } label: {
                                Label("Edit Profile", systemImage: "pencil.circle")
                            }
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
                            Button {
                                showShareSheet = true
                            } label: {
                                Label("Invite a Friend", systemImage: "person.badge.plus")
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
            .sheet(isPresented: $showingAddTask) {
                AddTaskView(children: children)
            }
            .sheet(isPresented: $showingChildren) {
                ChildrenManagementView()
            }
            .sheet(isPresented: $showNotificationCenter) {
                NotificationCenterView()
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
            }
            .sheet(isPresented: $showSubscription) {
                SubscriptionView()
            }
            .sheet(isPresented: $showRedemptionApprovals) {
                RedemptionApprovalsView()
            }
            .sheet(isPresented: $showRewardsHistory) {
                RewardsHistoryView(redemptions: allRedemptions.sorted { $0.createdAt > $1.createdAt }, isParent: true)
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [parentShareMessage, appStoreURL])
            }
            .sheet(isPresented: $showPendingApprovals) {
                PendingApprovalsView { reward in
                    celebrationReward = reward
                    showCelebration = true
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
            .task {
                archiveOldTasks()
            }
        }
    }

    private func archiveOldTasks() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let toArchive = tasks.filter { $0.isApproved && !$0.isArchived && $0.targetDate < cutoff }
        guard !toArchive.isEmpty else { return }
        for task in toArchive {
            task.isArchived = true
        }
    }

    private var childrenStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(children) { child in
                    VStack(spacing: 4) {
                        NavigationLink(destination: ChildTasksView(
                            child: child,
                            tasks: activeTasks.filter { $0.assignedTo == child.name },
                            allChildren: children
                        )) {
                            VStack(spacing: 4) {
                                AvatarView(avatarId: child.avatar, size: 44)

                                Text(child.name)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .lineLimit(1)
                            }
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
            .padding(.vertical, 6)
        }
    }

    private func sendReminder(to child: FamilyMember) {
        let openToday = activeTasks.filter {
            $0.assignedTo == child.name && $0.isOpen
            && Calendar.current.isDateInToday($0.targetDate)
        }
        let count = openToday.count
        let taskList = openToday.prefix(3).map { $0.name }.joined(separator: ", ")
        let body = count == 1
            ? "Don't forget: \"\(taskList)\" is due today!"
            : "You have \(count) tasks due today: \(taskList)\(count > 3 ? "..." : "")"

        Task {
            await cloudKitManager.sendRemoteNotification(
                familyCode: authManager.familyCode,
                title: "Reminder from \(authManager.userName)",
                body: body,
                category: "TASK_REMINDER",
                senderAvatar: authManager.avatar
            )
        }
        reminderSentChildName = child.name
        showReminderSent = true
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

    private func scheduleStickyNote(from tips: [String]) {
        let delay = Double.random(in: 15...45)
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
                .foregroundStyle(.white.opacity(0.3))
            Text(showOpenOnly ? "All caught up!" : "No tasks yet")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.7))
            Text(showOpenOnly ? "No open tasks remaining." : "Tap the button below to get started.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var groupListContent: some View {
        LazyVStack(spacing: 12) {
            ForEach(groupedTasks, id: \.key) { group in
                NavigationLink(destination: DateTasksView(
                    dateLabel: group.key,
                    tasks: group.tasks,
                    children: children
                )) {
                    GroupCard(dateLabel: group.key, count: group.tasks.count)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var tierBanner: some View {
        Button {
            showSubscription = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: subscriptionManager.tier == .family ? "house.fill" : "sparkles")
                    .font(.caption)
                    .foregroundStyle(subscriptionManager.tier == .family ? calmAccent : .orange)

                Text(subscriptionManager.tier == .free ? "Free Plan" : "Family Plan")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))

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
            Label("Add Task", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(.white.opacity(0.2), in: Capsule())
                .foregroundStyle(.white)
        }
        .shadow(color: calmAccent.opacity(0.3), radius: 8, y: 4)
    }
}

// MARK: - Group Card

struct GroupCard: View {
    let dateLabel: String
    let count: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(dateLabel)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("\(count) task\(count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(16)
        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Date Tasks View

struct DateTasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Environment(AuthManager.self) private var authManager
    @Query(sort: \Item.targetDate) private var allTasks: [Item]
    let dateLabel: String
    let tasks: [Item]
    let children: [FamilyMember]
    @State private var taskToDelete: Item?
    @State private var taskToEdit: Item?
    @State private var taskToApprove: Item?
    @State private var showingAddTask = false
    @State private var showTooEarlyAlert = false
    @State private var tooEarlyTask: Item?
    @State private var showCelebration = false
    @State private var celebrationReward: Double = 0

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(tasks) { task in
                        TaskRow(
                            task: task,
                            showAssignee: true,
                            onApprove: {
                                if !task.canComplete {
                                    tooEarlyTask = task
                                    showTooEarlyAlert = true
                                } else {
                                    taskToApprove = task
                                }
                            },
                            onEdit: { taskToEdit = task },
                            onDelete: { taskToDelete = task }
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 2)
                        .background(.white.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 12)
                }

                Button {
                    showingAddTask = true
                } label: {
                    Label("Add Task", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.2), in: Capsule())
                        .foregroundStyle(.white)
                }
                .shadow(color: calmAccent.opacity(0.3), radius: 8, y: 4)
                .padding(.bottom, 16)
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationTitle(dateLabel)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddTask) {
            AddTaskView(children: children)
        }
        .alert(taskToDelete?.isApproved == true ? "Delete Completed Task?" : "Delete Task", isPresented: Binding(
            get: { taskToDelete != nil },
            set: { if !$0 { taskToDelete = nil } }
        )) {
            if let task = taskToDelete {
                if task.isRecurring {
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
        } message: {
            if let task = taskToDelete {
                if task.isApproved && task.reward > 0 {
                    if task.isRecurring {
                        let matching = allTasks.filter {
                            $0.name == task.name && $0.assignedTo == task.assignedTo
                            && $0.isRecurring && !$0.isArchived
                        }
                        let approvedCoins = matching.filter { $0.isApproved && $0.reward > 0 }.reduce(0) { $0 + Int($1.reward) }
                        Text("Warning: This is a completed task worth \(Int(task.reward)) coins. Deleting it will deduct coins from \(task.assignedTo.isEmpty ? "the" : task.assignedTo + "'s") balance.\n\nDeleting all recurring instances would deduct \(approvedCoins) coins total.")
                    } else {
                        Text("Warning: This task has been completed and \(Int(task.reward)) coins were awarded to \(task.assignedTo.isEmpty ? "you" : task.assignedTo). Deleting it will deduct those coins from the balance.")
                    }
                } else if task.isRecurring {
                    let count = allTasks.filter {
                        $0.name == task.name && $0.assignedTo == task.assignedTo
                        && $0.isOpen && $0.isRecurring && !$0.isArchived
                    }.count
                    Text("\"\(task.name)\" is a recurring task with \(count) open instances. Delete just this one or all of them?")
                } else {
                    Text("Are you sure you want to delete \"\(task.name)\"?")
                }
            }
        }
        .sheet(item: $taskToEdit) { task in
            EditTaskView(task: task, children: children)
        }
        .alert(
            taskToApprove?.isInReview == true ? "Approve Task?" : "Mark as Complete?",
            isPresented: Binding(
                get: { taskToApprove != nil },
                set: { if !$0 { taskToApprove = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) {
                taskToApprove = nil
            }
            Button(taskToApprove?.isInReview == true ? "Approve" : "Complete") {
                if let task = taskToApprove {
                    handleApproval(task: task)
                }
                taskToApprove = nil
            }
        } message: {
            if let task = taskToApprove {
                if task.isInReview {
                    Text("Approve \"\(task.name)\"? This cannot be undone.")
                } else {
                    Text("Mark \"\(task.name)\" as complete? This cannot be undone.")
                }
            }
        }
        .alert("Not Yet! ⏰", isPresented: $showTooEarlyAlert) {
            Button("Got It", role: .cancel) { tooEarlyTask = nil }
        } message: {
            if let task = tooEarlyTask {
                Text("This task is scheduled for \(task.dueDateLabel). It can be completed when the day arrives!")
            }
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

    private func deductCoinsIfNeeded(_ task: Item) {
        guard task.isApproved, task.reward > 0, !task.assignedTo.isEmpty else { return }
        if let child = children.first(where: { $0.name == task.assignedTo }) {
            child.totalEarned = max(0, child.totalEarned - task.reward)
            let familyCode = authManager.familyCode
            Task { await cloudKitManager.pushMember(child, familyCode: familyCode) }
        }
    }

    private func deleteSingleTask(_ task: Item) {
        deductCoinsIfNeeded(task)
        notificationManager.cancelTaskReminder(taskId: task.id)
        let taskID = task.id
        withAnimation { modelContext.delete(task) }
        Task { await cloudKitManager.deleteRemoteTask(taskID) }
    }

    private func deleteAllRecurring(like task: Item) {
        let matching = allTasks.filter {
            $0.name == task.name && $0.assignedTo == task.assignedTo
            && $0.isRecurring && !$0.isArchived
        }
        var taskIDs: [UUID] = []
        for t in matching {
            deductCoinsIfNeeded(t)
            notificationManager.cancelTaskReminder(taskId: t.id)
            taskIDs.append(t.id)
            withAnimation { modelContext.delete(t) }
        }
        Task { await cloudKitManager.deleteRemoteTasks(taskIDs) }
    }

    private func handleApproval(task: Item) {
        task.status = "approved"
        let snapshot = CloudKitManager.TaskSnapshot(task)
        if task.reward > 0 && !task.assignedTo.isEmpty {
            if let child = children.first(where: { $0.name == task.assignedTo }) {
                child.totalEarned += task.reward
                let familyCode = authManager.familyCode
                Task { await cloudKitManager.pushMember(child, familyCode: familyCode) }
            }
        }
        if !task.assignedTo.isEmpty {
            notificationManager.sendTaskApprovedNotification(
                taskName: task.name,
                childName: task.assignedTo,
                reward: task.reward
            )
        }
        let familyCode = authManager.familyCode
        let taskName = task.name
        let childName = task.assignedTo
        let reward = task.reward
        Task {
            await cloudKitManager.pushTaskSnapshot(snapshot, familyCode: familyCode)
            if !childName.isEmpty {
                let rewardText = reward > 0 ? " You earned \(Int(reward)) coins!" : ""
                await cloudKitManager.sendRemoteNotification(
                    familyCode: familyCode,
                    title: "Task Approved!",
                    body: "\"\(taskName)\" has been approved.\(rewardText)",
                    category: "TASK_APPROVED",
                    senderAvatar: authManager.avatar
                )
            }
        }
        SoundManager.shared.playApplause()
        celebrationReward = task.reward
        showCelebration = true
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
    let child: FamilyMember
    let tasks: [Item]
    let allChildren: [FamilyMember]
    @State private var showOpenOnly = true
    @State private var taskToEdit: Item?
    @State private var taskToDelete: Item?
    @State private var taskToApprove: Item?
    @State private var showCelebration = false
    @State private var celebrationReward: Double = 0
    @State private var showingAddTask = false
    @State private var showTooEarlyAlert = false
    @State private var tooEarlyTask: Item?
    @State private var showReminderSent = false

    private var childTotalEarned: Int {
        allTasks
            .filter { $0.assignedTo == child.name && $0.isApproved && $0.reward > 0 }
            .reduce(0) { $0 + Int($1.reward) }
    }

    private var childRedeemedCoins: Int {
        allRedemptions
            .filter { $0.childName == child.name && ($0.isApproved || $0.isFulfilled || $0.isPending) }
            .reduce(0) { $0 + $1.coinAmount }
    }

    private var childAvailableCoins: Int {
        max(0, childTotalEarned - childRedeemedCoins)
    }

    private var filteredTasks: [Item] {
        showOpenOnly ? tasks.filter { !$0.isApproved } : tasks
    }

    private var groupedTasks: [(key: String, tasks: [Item])] {
        let grouped = Dictionary(grouping: filteredTasks) { $0.dueDateLabel }
        return grouped
            .map { (key: $0.key, tasks: $0.value) }
            .sorted { first, second in
                guard let d1 = first.tasks.first?.targetDate,
                      let d2 = second.tasks.first?.targetDate else { return false }
                return d1 < d2
            }
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                childHeader

                if filteredTasks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: showOpenOnly ? "checkmark.circle" : "tray")
                            .font(.system(size: 56))
                            .foregroundStyle(.white.opacity(0.3))
                        Text(showOpenOnly ? "All caught up!" : "No tasks yet")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(groupedTasks, id: \.key) { group in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(group.key)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.6))
                                        .padding(.leading, 4)

                                    ForEach(group.tasks) { task in
                                        TaskRow(
                                            task: task,
                                            onApprove: {
                                                if !task.canComplete {
                                                    tooEarlyTask = task
                                                    showTooEarlyAlert = true
                                                } else {
                                                    taskToApprove = task
                                                }
                                            },
                                            onEdit: { taskToEdit = task },
                                            onDelete: { taskToDelete = task }
                                        )
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 2)
                                        .background(.white.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .strokeBorder(
                                                    task.isInReview ? .orange.opacity(0.3) : .white.opacity(0.25),
                                                    lineWidth: 1
                                                )
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                }

                Button {
                    showingAddTask = true
                } label: {
                    Label("Add Task", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(calmAccent, in: RoundedRectangle(cornerRadius: 16))
                        .shadow(color: calmAccent.opacity(0.4), radius: 8, y: 4)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationTitle("\(child.name)'s Tasks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
        .alert(taskToDelete?.isApproved == true ? "Delete Completed Task?" : "Delete Task", isPresented: Binding(
            get: { taskToDelete != nil },
            set: { if !$0 { taskToDelete = nil } }
        )) {
            if let task = taskToDelete {
                if task.isRecurring {
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
        } message: {
            if let task = taskToDelete {
                if task.isApproved && task.reward > 0 {
                    if task.isRecurring {
                        let matching = allTasks.filter {
                            $0.name == task.name && $0.assignedTo == task.assignedTo
                            && $0.isRecurring && !$0.isArchived
                        }
                        let approvedCoins = matching.filter { $0.isApproved && $0.reward > 0 }.reduce(0) { $0 + Int($1.reward) }
                        Text("Warning: This is a completed task worth \(Int(task.reward)) coins. Deleting it will deduct coins from \(task.assignedTo.isEmpty ? "the" : task.assignedTo + "'s") balance.\n\nDeleting all recurring instances would deduct \(approvedCoins) coins total.")
                    } else {
                        Text("Warning: This task has been completed and \(Int(task.reward)) coins were awarded to \(task.assignedTo.isEmpty ? "you" : task.assignedTo). Deleting it will deduct those coins from the balance.")
                    }
                } else if task.isRecurring {
                    let count = allTasks.filter {
                        $0.name == task.name && $0.assignedTo == task.assignedTo
                        && $0.isOpen && $0.isRecurring && !$0.isArchived
                    }.count
                    Text("\"\(task.name)\" is a recurring task with \(count) open instances. Delete just this one or all of them?")
                } else {
                    Text("Are you sure you want to delete \"\(task.name)\"?")
                }
            }
        }
        .alert(
            taskToApprove?.isInReview == true ? "Approve Task?" : "Mark as Complete?",
            isPresented: Binding(
                get: { taskToApprove != nil },
                set: { if !$0 { taskToApprove = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { taskToApprove = nil }
            Button(taskToApprove?.isInReview == true ? "Approve" : "Complete") {
                if let task = taskToApprove {
                    task.status = "approved"
                    let snapshot = CloudKitManager.TaskSnapshot(task)
                    if task.reward > 0 {
                        child.totalEarned += task.reward
                    }
                    notificationManager.sendTaskApprovedNotification(
                        taskName: task.name,
                        childName: child.name,
                        reward: task.reward
                    )
                    let familyCode = authManager.familyCode
                    let taskName = task.name
                    let reward = task.reward
                    Task {
                        await cloudKitManager.pushTaskSnapshot(snapshot, familyCode: familyCode)
                        await cloudKitManager.pushMember(child, familyCode: familyCode)
                        let rewardText = reward > 0 ? " You earned \(Int(reward)) coins!" : ""
                        await cloudKitManager.sendRemoteNotification(
                            familyCode: familyCode,
                            title: "Task Approved!",
                            body: "\"\(taskName)\" has been approved.\(rewardText)",
                            category: "TASK_APPROVED",
                            senderAvatar: authManager.avatar
                        )
                    }
                    SoundManager.shared.playApplause()
                    celebrationReward = task.reward
                    showCelebration = true
                }
                taskToApprove = nil
            }
        } message: {
            if let task = taskToApprove {
                if task.isInReview {
                    Text("Approve \"\(task.name)\"? This cannot be undone.")
                } else {
                    Text("Mark \"\(task.name)\" as complete? This cannot be undone.")
                }
            }
        }
        .sheet(item: $taskToEdit) { task in
            EditTaskView(task: task, children: allChildren)
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView(children: allChildren, preselectedChild: child.name)
        }
        .alert("Not Yet! ⏰", isPresented: $showTooEarlyAlert) {
            Button("Got It", role: .cancel) { tooEarlyTask = nil }
        } message: {
            if let task = tooEarlyTask {
                Text("This task is scheduled for \(task.dueDateLabel). It can be completed when the day arrives!")
            }
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

    private var todayOpenTasks: [Item] {
        tasks.filter { $0.isOpen && Calendar.current.isDateInToday($0.targetDate) }
    }

    private var childHeader: some View {
        HStack(spacing: 14) {
            AvatarView(avatarId: child.avatar, size: 56)

            VStack(alignment: .leading, spacing: 6) {
                Text(child.name)
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    Text("\(childAvailableCoins) coins")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.yellow.opacity(0.85))
                    if childRedeemedCoins > 0 {
                        Text("(\(childRedeemedCoins) redeemed)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
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
                    .foregroundStyle(.white)
                Text("completed")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
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
        let count = todayOpenTasks.count
        let taskList = todayOpenTasks.prefix(3).map { $0.name }.joined(separator: ", ")
        let body = count == 1
            ? "Don't forget: \"\(taskList)\" is due today!"
            : "You have \(count) tasks due today: \(taskList)\(count > 3 ? "..." : "")"

        Task {
            await cloudKitManager.sendRemoteNotification(
                familyCode: authManager.familyCode,
                title: "Reminder from \(authManager.userName)",
                body: body,
                category: "TASK_REMINDER",
                senderAvatar: authManager.avatar
            )
        }
        showReminderSent = true
    }

    private func deductCoinsIfNeeded(_ task: Item) {
        guard task.isApproved, task.reward > 0, !task.assignedTo.isEmpty else { return }
        if let member = allChildren.first(where: { $0.name == task.assignedTo }) {
            member.totalEarned = max(0, member.totalEarned - task.reward)
            let familyCode = authManager.familyCode
            Task { await cloudKitManager.pushMember(member, familyCode: familyCode) }
        }
    }

    private func deleteSingleTask(_ task: Item) {
        deductCoinsIfNeeded(task)
        notificationManager.cancelTaskReminder(taskId: task.id)
        let taskID = task.id
        withAnimation { modelContext.delete(task) }
        Task { await cloudKitManager.deleteRemoteTask(taskID) }
    }

    private func deleteAllRecurring(like task: Item) {
        let matching = allTasks.filter {
            $0.name == task.name && $0.assignedTo == task.assignedTo
            && $0.isRecurring && !$0.isArchived
        }
        var taskIDs: [UUID] = []
        for t in matching {
            deductCoinsIfNeeded(t)
            notificationManager.cancelTaskReminder(taskId: t.id)
            taskIDs.append(t.id)
            withAnimation { modelContext.delete(t) }
        }
        Task { await cloudKitManager.deleteRemoteTasks(taskIDs) }
    }
}

// MARK: - Task Row

struct TaskRow: View {
    @Bindable var task: Item
    var showAssignee: Bool = false
    var onApprove: (() -> Void)?
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    private var statusColor: Color {
        if task.isApproved { return .green }
        if task.isInReview { return .orange }
        return .white.opacity(0.4)
    }

    private var statusLabel: String {
        if task.isApproved { return "Done" }
        if task.isInReview { return "Review" }
        return "To Do"
    }

    var body: some View {
        HStack(spacing: 14) {
            Button {
                guard task.isOpen || task.isInReview else { return }
                if task.isInReview || task.assignedTo.isEmpty || task.createdByChild {
                    onApprove?()
                }
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
                                .foregroundStyle(.white)
                        } else if task.isInReview {
                            Circle()
                                .fill(.orange)
                                .frame(width: 32, height: 32)
                            Image(systemName: "clock")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    Text(statusLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .disabled(task.isApproved)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.name)
                    .font(.body)
                    .strikethrough(task.isApproved)
                    .foregroundStyle(task.isApproved ? .white.opacity(0.35) : .white)

                HStack(spacing: 6) {
                    if task.isInReview {
                        Text("In Review")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    } else if task.isApproved {
                        Text("Approved")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    }

                    Text(task.targetDate, format: .dateTime.hour().minute())
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white)

                    if task.reward > 0 {
                        Text("•")
                            .foregroundStyle(.white.opacity(0.3))
                        CoinDisplay(count: Int(task.reward), earned: task.isApproved)
                    }

                    if showAssignee && !task.assignedTo.isEmpty {
                        Text("•")
                            .foregroundStyle(.white.opacity(0.3))
                        Label(task.assignedTo, systemImage: "person.fill")
                            .font(.caption)
                            .foregroundStyle(calmAccent.opacity(0.8))
                    }
                }
            }

            Spacer()

            if onEdit != nil || onDelete != nil {
                HStack(spacing: 14) {
                    if let onEdit {
                        Button {
                            onEdit()
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(calmAccent.opacity(0.6), in: Circle())
                                .overlay(Circle().strokeBorder(calmAccent.opacity(0.4), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }

                    if let onDelete {
                        Button {
                            onDelete()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(.red.opacity(0.5), in: Circle())
                                .overlay(Circle().strokeBorder(.red.opacity(0.4), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .opacity(task.isApproved ? 0.7 : 1)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                onEdit?()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(calmAccent)
        }
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
    let children: [FamilyMember]
    var preselectedChild: String = ""

    @State private var taskName = ""
    @State private var targetDate = Date()
    @State private var selectedChild = ""
    @State private var rewardText = ""
    @State private var recurrenceType: RecurrenceType = .none
    @State private var occurrences = 10
    @State private var selectedWeekdays: Set<Int> = []
    @State private var selectedTemplate: TaskTemplate?
    @State private var useSmartScheduler = false
    @State private var smartInput = ""
    @State private var parsedTask: ParsedTask?
    @State private var showQuotaAlert = false

    private var isValid: Bool {
        !taskName.trimmingCharacters(in: .whitespaces).isEmpty
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

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

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

                        templatePicker

                        if let remaining = subscriptionManager.tasksRemaining(allTasks: allTasks) {
                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: remaining == 0 ? "xmark.circle.fill" : remaining <= 10 ? "exclamationmark.triangle.fill" : "info.circle.fill")
                                        .foregroundStyle(remaining == 0 ? .red : remaining <= 10 ? .orange : .cyan)
                                    Text(remaining == 0 ? "Task limit reached" : "\(remaining) tasks remaining this month")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.white.opacity(0.7))
                                    Spacer()
                                    Text(subscriptionManager.tier.rawValue.capitalized)
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.white.opacity(0.5))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(.white.opacity(0.1), in: Capsule())
                                }

                                if remaining <= 10 {
                                    NavigationLink {
                                        SubscriptionView()
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
                                    .strokeBorder(
                                        remaining == 0 ? .red.opacity(0.2) : remaining <= 10 ? .orange.opacity(0.2) : .cyan.opacity(0.15),
                                        lineWidth: 1
                                    )
                            )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Task Name")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))

                            TextField("What needs to be done?", text: $taskName)
                                .font(.body)
                                .foregroundStyle(.white)
                                .padding(14)
                                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                                )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(recurrenceType == .none ? "Due Date" : "Start Date")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))

                            DatePicker(
                                "",
                                selection: $targetDate,
                                in: Date()...,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                            )
                        }

                        recurrenceSection

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reward (coins)")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))

                            HStack(spacing: 10) {
                                Image(systemName: "star.circle.fill")
                                    .foregroundStyle(.yellow)

                                TextField("0", text: $rewardText)
                                    .font(.body)
                                    .foregroundStyle(.white)
                                    .keyboardType(.decimalPad)
                            }
                            .padding(14)
                            .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                            )
                        }

                        if !children.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Assign To")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))

                                VStack(spacing: 8) {
                                    childChip(name: authManager.userName, isSelected: selectedChild.isEmpty) {
                                        selectedChild = ""
                                    }

                                    ForEach(children) { child in
                                        childChip(name: child.name, isSelected: selectedChild == child.name) {
                                            selectedChild = child.name
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
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if selectedChild.isEmpty && !preselectedChild.isEmpty {
                    selectedChild = preselectedChild
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
                        for date in dates {
                            let task = Item(
                                name: trimmedName,
                                targetDate: date,
                                assignedTo: selectedChild,
                                reward: rewardValue,
                                isRecurring: recurring
                            )
                            modelContext.insert(task)
                            createdTasks.append(task)
                            subscriptionManager.recordTaskCreation()
                            notificationManager.scheduleTaskReminder(
                                taskId: task.id,
                                taskName: trimmedName,
                                assignedTo: selectedChild,
                                dueDate: date
                            )
                        }
                        let familyCode = authManager.familyCode
                        let childName = selectedChild
                        let parentName = authManager.userName
                        let taskCount = createdTasks.count
                        Task {
                            for task in createdTasks {
                                await cloudKitManager.pushTask(task, familyCode: familyCode)
                            }
                            if !childName.isEmpty {
                                await cloudKitManager.sendRemoteNotification(
                                    familyCode: familyCode,
                                    title: "New Task Assigned",
                                    body: "\(parentName) assigned \"\(trimmedName)\" to \(childName)" + (taskCount > 1 ? " (\(taskCount) tasks)" : ""),
                                    category: "TASK_ASSIGNED",
                                    senderAvatar: authManager.avatar
                                )
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
        .alert("Task Limit Reached", isPresented: $showQuotaAlert) {
            NavigationLink("Upgrade Plan") {
                SubscriptionView()
            }
            Button("OK", role: .cancel) { }
        } message: {
            if !subscriptionManager.canCreateMoreTasks(allTasks: allTasks) {
                if let limit = subscriptionManager.maxTasksPerMonth {
                    Text("You've used all \(limit) tasks for this month on the \(subscriptionManager.tier.rawValue.capitalized) plan. Upgrade your plan for more tasks, or wait until next month.")
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
                .foregroundStyle(.white.opacity(0.7))

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
                                    .foregroundStyle(selectedTemplate?.name == template.name ? .white : .white.opacity(0.7))
                                    .lineLimit(1)
                            }
                            .frame(width: 90, height: 70)
                            .background(
                                selectedTemplate?.name == template.name ? template.color.opacity(0.6) : .white.opacity(0.1),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        selectedTemplate?.name == template.name ? template.color : .white.opacity(0.1),
                                        lineWidth: 1
                                    )
                            )
                        }
                    }
                }
            }
        }
    }

    private var recurrenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recurrence")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))

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
                                        selectedWeekdays.contains(day) ? calmAccent : .white.opacity(0.15),
                                        in: Circle()
                                    )
                                    .foregroundStyle(selectedWeekdays.contains(day) ? .white : .white.opacity(0.5))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                Stepper(value: $occurrences, in: 2...stepperMax) {
                    HStack {
                        Text("Repeat for")
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(occurrences) \(recurrenceUnitLabel)")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .font(.subheadline)
                }
                .tint(.white)
                .padding(12)
                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
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
                        .foregroundStyle(.white.opacity(0.5))
                }

                TextField("e.g. Study time for Arya tomorrow 5pm 3 coins daily", text: $smartInput, axis: .vertical)
                    .font(.body)
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .padding(14)
                    .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
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
                    .background(smartInput.trimmingCharacters(in: .whitespaces).isEmpty ? .white.opacity(0.1) : calmAccent, in: RoundedRectangle(cornerRadius: 12))
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
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(12)
                    .background(.green.opacity(0.1))

                    VStack(spacing: 12) {
                        smartRow(icon: "pencil.line", label: "Task", value: parsed.name.isEmpty ? "—" : parsed.name)
                        smartRow(icon: "calendar", label: "Date", value: parsed.hasDate ? parsed.targetDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()) : "Not detected — defaults to now")
                        smartRow(icon: "person.fill", label: "Assign To", value: parsed.assignedTo.isEmpty ? (preselectedChild.isEmpty ? authManager.userName : preselectedChild) : parsed.assignedTo)
                        smartRow(icon: "star.circle.fill", label: "Reward", value: parsed.reward > 0 ? "\(parsed.reward) coins" : "None")
                        smartRow(icon: "repeat", label: "Recurrence", value: parsed.recurrence.rawValue)
                    }
                    .padding(12)
                }
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
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
                    .background(parsed.name.isEmpty ? .white.opacity(0.1) : calmAccent, in: RoundedRectangle(cornerRadius: 12))
                }
                .disabled(parsed.name.isEmpty)
            }
        }
    }

    private func smartRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 20)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.white)
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
        selectedChild = parsed.assignedTo.isEmpty ? preselectedChild : parsed.assignedTo
        rewardText = parsed.reward > 0 ? "\(parsed.reward)" : ""
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
                assignedTo: selectedChild,
                reward: Double(rewardText) ?? 0,
                isRecurring: recurring
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
                    if !selectedChild.isEmpty {
                        await cloudKitManager.sendRemoteNotification(
                            familyCode: authManager.familyCode,
                            title: "New Task Assigned",
                            body: "\"\(trimmedName)\" assigned to \(selectedChild)",
                            category: "TASK_ASSIGNED",
                            senderAvatar: authManager.avatar
                        )
                    }
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

    private func childChip(name: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? calmAccent : .white.opacity(0.3))
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(12)
            .background(
                isSelected ? calmAccent.opacity(0.15) : .white.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isSelected ? calmAccent.opacity(0.4) : .white.opacity(0.15),
                        lineWidth: 1
                    )
            )
        }
    }
}

// MARK: - Edit Task View (Parent)

struct EditTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Environment(AuthManager.self) private var authManager
    @Bindable var task: Item
    let children: [FamilyMember]

    @State private var taskName: String
    @State private var targetDate: Date
    @State private var selectedChild: String
    @State private var rewardText: String

    init(task: Item, children: [FamilyMember]) {
        self.task = task
        self.children = children
        _taskName = State(initialValue: task.name)
        _targetDate = State(initialValue: task.targetDate)
        _selectedChild = State(initialValue: task.assignedTo)
        _rewardText = State(initialValue: task.reward > 0 ? String(format: "%.2f", task.reward) : "")
    }

    private var isValid: Bool {
        !taskName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var rewardValue: Double {
        Double(rewardText) ?? 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 20)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Task Name")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))

                            TextField("What needs to be done?", text: $taskName)
                                .font(.body)
                                .foregroundStyle(.white)
                                .padding(14)
                                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                                )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Due Date")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))

                            DatePicker(
                                "",
                                selection: $targetDate,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                            )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reward (coins)")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))

                            HStack(spacing: 10) {
                                Image(systemName: "star.circle.fill")
                                    .foregroundStyle(.yellow)

                                TextField("0", text: $rewardText)
                                    .font(.body)
                                    .foregroundStyle(.white)
                                    .keyboardType(.decimalPad)
                            }
                            .padding(14)
                            .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                            )
                        }

                        if !children.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Assign To")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))

                                VStack(spacing: 8) {
                                    editChildChip(name: authManager.userName, isSelected: selectedChild.isEmpty) {
                                        selectedChild = ""
                                    }

                                    ForEach(children) { child in
                                        editChildChip(name: child.name, isSelected: selectedChild == child.name) {
                                            selectedChild = child.name
                                        }
                                    }
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        task.name = taskName.trimmingCharacters(in: .whitespaces)
                        task.targetDate = targetDate
                        task.assignedTo = selectedChild
                        task.reward = rewardValue
                        notificationManager.cancelTaskReminder(taskId: task.id)
                        notificationManager.scheduleTaskReminder(
                            taskId: task.id,
                            taskName: task.name,
                            assignedTo: task.assignedTo,
                            dueDate: targetDate
                        )
                        let familyCode = authManager.familyCode
                        Task { await cloudKitManager.pushTask(task, familyCode: familyCode) }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func editChildChip(name: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? calmAccent : .white.opacity(0.3))
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(12)
            .background(
                isSelected ? calmAccent.opacity(0.15) : .white.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isSelected ? calmAccent.opacity(0.4) : .white.opacity(0.15),
                        lineWidth: 1
                    )
            )
        }
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
    @State private var memberToRemove: FamilyMember?

    private var parents: [FamilyMember] {
        var seen = Set<String>()
        return allMembers.filter { $0.isParent }.filter { seen.insert($0.name).inserted }
    }
    private var children: [FamilyMember] {
        var seen = Set<String>()
        return allMembers.filter { $0.isChild && $0.isAccepted }.filter { seen.insert($0.name).inserted }
    }
    private var pendingMembers: [FamilyMember] {
        allMembers.filter { $0.isChild && !$0.isAccepted }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

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
            .toolbarColorScheme(.dark, for: .navigationBar)
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
                .foregroundStyle(.white.opacity(0.5))

            Text(authManager.familyCode)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .tracking(6)

            Text("New members can use this code to join your family")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.35))

            ShareLink(
                item: "Join my family on Taskee! Use invite code: \(authManager.familyCode)"
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
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
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
                            .foregroundStyle(.white)
                        Text("Wants to join your family")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
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
                            await cloudKitManager.sendRemoteNotification(
                                familyCode: familyCode,
                                title: "Welcome to the Family!",
                                body: "\(member.name), your parent approved your request. You're all set!",
                                category: "MEMBER_ACCEPTED",
                                senderAvatar: authManager.avatar
                            )
                        }
                    } label: {
                        Text("Accept")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.green, in: Capsule())
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
                .foregroundStyle(.white.opacity(0.5))

            if members.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.25))
                        Text("No members yet")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.35))
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
                                .foregroundStyle(.white)

                            if member.isChild {
                                Text("Earned: \(Int(member.totalEarned)) coins")
                                    .font(.caption)
                                    .foregroundStyle(.yellow.opacity(0.8))
                            } else {
                                Text("Parent")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                        }

                        Spacer()

                        if canRemove {
                            Button {
                                memberToRemove = member
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                        }
                    }
                    .padding(14)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.white.opacity(0.15), lineWidth: 1)
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
                        .foregroundStyle(.white)
                    Text("Your \(subscriptionManager.tier.rawValue.capitalized) plan allows up to \(subscriptionManager.maxMembers) members.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()
            }

            NavigationLink {
                SubscriptionView()
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
                .foregroundStyle(.white)
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
    @Query private var children: [FamilyMember]
    var onApproved: ((Double) -> Void)?
    @State private var taskToApprove: Item?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                if pendingTasks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 56))
                            .foregroundStyle(.white.opacity(0.3))
                        Text("All caught up!")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.7))
                        Text("No tasks pending approval.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.4))
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
            .toolbarColorScheme(.dark, for: .navigationBar)
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
                        task.status = "approved"
                        let snapshot = CloudKitManager.TaskSnapshot(task)
                        withAnimation(.snappy) {
                            if task.reward > 0 && !task.assignedTo.isEmpty {
                                if let child = children.first(where: { $0.name == task.assignedTo }) {
                                    child.totalEarned += task.reward
                                    let familyCode = authManager.familyCode
                                    Task { await cloudKitManager.pushMember(child, familyCode: familyCode) }
                                }
                            }
                            onApproved?(task.reward)
                        }
                        let familyCode = authManager.familyCode
                        let taskName = task.name
                        let childName = task.assignedTo
                        let reward = task.reward
                        Task {
                            await cloudKitManager.pushTaskSnapshot(snapshot, familyCode: familyCode)
                            if !childName.isEmpty {
                                let rewardText = reward > 0 ? " You earned \(Int(reward)) coins!" : ""
                                await cloudKitManager.sendRemoteNotification(
                                    familyCode: familyCode,
                                    title: "Task Approved!",
                                    body: "\"\(taskName)\" has been approved.\(rewardText)",
                                    category: "TASK_APPROVED",
                                    senderAvatar: authManager.avatar
                                )
                            }
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
                Image(systemName: "clock.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 3) {
                    Text(task.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white)

                    HStack(spacing: 6) {
                        if !task.assignedTo.isEmpty {
                            Label(task.assignedTo, systemImage: "person.fill")
                                .font(.caption)
                                .foregroundStyle(calmAccent.opacity(0.8))
                        }

                        Text(task.dueDateLabel)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.45))

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
                    let taskName = task.name
                    let childName = task.assignedTo
                    Task {
                        await cloudKitManager.pushTaskSnapshot(snapshot, familyCode: familyCode)
                        if !childName.isEmpty {
                            await cloudKitManager.sendRemoteNotification(
                                familyCode: familyCode,
                                title: "Task Needs Redo",
                                body: "\"\(taskName)\" was sent back. Please try again.",
                                category: "TASK_REJECTED",
                                senderAvatar: authManager.avatar
                            )
                        }
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
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
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
    var onComplete: () -> Void

    private var children: [FamilyMember] {
        var seen = Set<String>()
        return allMembers.filter { $0.isChild }.filter { seen.insert($0.name).inserted }
    }

    @State private var newChildName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 20)

                        VStack(spacing: 12) {
                            Image(systemName: "party.popper.fill")
                                .font(.system(size: 52))
                                .foregroundStyle(.yellow)

                            Text("You're all set, \(authManager.userName)!")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)

                            Text("Share the invite code below with your family members so they can join. You can also add children here to get started right away!")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                        }

                        inviteCodeCard

                        if !children.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Children (\(children.count)/\(subscriptionManager.maxMembers))")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))

                                ForEach(children) { child in
                                    HStack {
                                        AvatarView(avatarId: child.avatar, size: 36)

                                        Text(child.name)
                                            .font(.body)
                                            .foregroundStyle(.white)

                                        Spacer()
                                    }
                                    .padding(14)
                                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                                    )
                                }
                            }
                        }

                        if subscriptionManager.canAddMember(currentCount: allMembers.count) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Add Child")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))

                                HStack(spacing: 10) {
                                    TextField("Child's name", text: $newChildName)
                                        .font(.body)
                                        .foregroundStyle(.white)
                                        .padding(12)
                                        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
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
                                    .foregroundStyle(.white.opacity(0.8))
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
            .toolbarColorScheme(.dark, for: .navigationBar)
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
                .foregroundStyle(.white.opacity(0.5))

            Text(authManager.familyCode)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .tracking(6)

            Text("Send this code to your children and other family members so they can join from their own device")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)

            ShareLink(
                item: "Join my family on Taskee! Use invite code: \(authManager.familyCode)"
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
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Edit Profile View

struct EditProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Query private var allMembers: [FamilyMember]

    @State private var name = ""
    @State private var selectedAvatar = ""

    private var myMember: FamilyMember? {
        allMembers.first { $0.appleUserID == authManager.appleUserID }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 12)

                        AvatarView(avatarId: selectedAvatar, size: 90)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Choose Avatar")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                                ForEach(avatarPresets, id: \.id) { preset in
                                    AvatarView(avatarId: preset.id, size: 50)
                                        .overlay(
                                            Circle().strokeBorder(selectedAvatar == preset.id ? avatarColor(for: preset.id) : .clear, lineWidth: 2)
                                        )
                                        .onTapGesture { selectedAvatar = preset.id }
                                }
                            }

                            Text("Animals")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.top, 4)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                                ForEach(animalAvatarPresets, id: \.id) { preset in
                                    AvatarView(avatarId: preset.id, size: 50)
                                        .overlay(
                                            Circle().strokeBorder(selectedAvatar == preset.id ? avatarColor(for: preset.id) : .clear, lineWidth: 2)
                                        )
                                        .onTapGesture { selectedAvatar = preset.id }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Name")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))

                            TextField("Enter your name", text: $name)
                                .font(.body)
                                .foregroundStyle(.white)
                                .padding(14)
                                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                                )
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
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
            }
        }
        .presentationDetents([.large])
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
    @State private var rejectTarget: RewardRedemption?
    @State private var rejectReason = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                if pendingRedemptions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "gift")
                            .font(.system(size: 56))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("No pending requests")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.85))
                        Text("All reward requests have been handled.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
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
            .toolbarColorScheme(.dark, for: .navigationBar)
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
                        let desc = redemption.itemDescription
                        Task {
                            _ = await cloudKitManager.pushRedemption(redemption, familyCode: familyCode)
                            await cloudKitManager.sendRemoteNotification(
                                familyCode: familyCode,
                                title: "Reward Request Declined",
                                body: "Your request for \"\(desc)\" was declined." + (rejectReason.isEmpty ? "" : " Reason: \(rejectReason)"),
                                category: "REWARD_REJECTED",
                                senderAvatar: authManager.avatar
                            )
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
                        .foregroundStyle(.white)

                    HStack(spacing: 6) {
                        Label(r.childName, systemImage: "person.fill")
                            .font(.caption)
                            .foregroundStyle(calmAccent.opacity(0.8))

                        Text("•")
                            .foregroundStyle(.white.opacity(0.5))

                        Label("\(r.coinAmount) coins", systemImage: "star.circle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.yellow.opacity(0.85))

                        Text("•")
                            .foregroundStyle(.white.opacity(0.5))

                        Text(r.typeLabel)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    Text(r.createdAt, format: .relative(presentation: .named))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
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
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.purple.opacity(0.2), lineWidth: 1)
        )
    }

    private func approveRedemption(_ r: RewardRedemption) {
        r.status = "approved"
        r.resolvedAt = Date()
        let familyCode = authManager.familyCode
        let desc = r.itemDescription
        let coins = r.coinAmount
        Task {
            _ = await cloudKitManager.pushRedemption(r, familyCode: familyCode)
            await cloudKitManager.sendRemoteNotification(
                familyCode: familyCode,
                title: "Reward Approved!",
                body: "Your request for \"\(desc)\" (\(coins) coins) was approved!",
                category: "REWARD_APPROVED",
                senderAvatar: authManager.avatar
            )
        }
    }
}

// MARK: - Subscription View

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var subscriptionManager
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
                name: "Free",
                icon: "person.2.fill",
                color: .gray,
                price: "$0",
                period: "forever",
                features: [
                    PlanFeature(text: "Up to 4 family members", included: true),
                    PlanFeature(text: "50 tasks per month", included: true),
                    PlanFeature(text: "20 pickup requests per day", included: true),
                    PlanFeature(text: "Basic notifications", included: true),
                    PlanFeature(text: "Priority support", included: false),
                ],
                monthlyID: nil,
                annualID: nil
            ),
            PlanInfo(
                tier: .family,
                name: "Family",
                icon: "house.fill",
                color: calmAccent,
                price: "$4.99",
                period: "/month",
                features: [
                    PlanFeature(text: "Up to 6 family members", included: true),
                    PlanFeature(text: "350 tasks per month", included: true),
                    PlanFeature(text: "30 pickup requests per day", included: true),
                    PlanFeature(text: "All notifications", included: true),
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
                    PlanFeature(text: "Unlimited tasks", included: true),
                    PlanFeature(text: "Unlimited pickup requests", included: true),
                    PlanFeature(text: "All notifications", included: true),
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
                AppBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        currentPlanBadge

                        ForEach(plans, id: \.name) { plan in
                            planCard(plan)
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
            .toolbarColorScheme(.dark, for: .navigationBar)
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
        HStack(spacing: 10) {
            Image(systemName: subscriptionManager.tier == .pro ? "crown.fill" : subscriptionManager.tier == .family ? "house.fill" : "person.2.fill")
                .font(.title3)
                .foregroundStyle(subscriptionManager.tier == .pro ? .orange : subscriptionManager.tier == .family ? calmAccent : .gray)

            VStack(alignment: .leading, spacing: 2) {
                Text("Current Plan")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                Text(subscriptionManager.tier.rawValue.capitalized)
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            Spacer()

            Text(subscriptionManager.tier == .free ? "Free" : "Active")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    (subscriptionManager.tier == .free ? Color.gray : Color.green).opacity(0.3),
                    in: Capsule()
                )
        }
        .padding(16)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
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
                        .foregroundStyle(.white)

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(planPrice(plan))
                            .font(.headline)
                            .foregroundStyle(.white)
                        if plan.tier != .free {
                            Text(plan.period)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
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
                            .foregroundStyle(feature.included ? .green : .white.opacity(0.25))

                        Text(feature.text)
                            .font(.subheadline)
                            .foregroundStyle(feature.included ? .white.opacity(0.8) : .white.opacity(0.3))

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
            isCurrent ? plan.color.opacity(0.08) : .white.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isCurrent ? plan.color.opacity(0.4) : .white.opacity(0.1),
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
                _ = await subscriptionManager.purchase(product)
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
                        .tint(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isAnnual ? plan.color : plan.color.opacity(0.4),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .foregroundStyle(.white)
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

    private var restoreButton: some View {
        Button {
            Task {
                await subscriptionManager.restorePurchases()
            }
        } label: {
            Text("Restore Purchases")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.vertical, 8)
        }
    }

    private var subscriptionLegalText: some View {
        VStack(spacing: 12) {
            Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscriptions automatically renew unless canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel your subscriptions in your App Store account settings.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            HStack(spacing: 16) {
                Link("Privacy Policy", destination: privacyPolicyURL)
                Link("Terms of Use", destination: termsOfUseURL)
                Link("Manage Subscriptions", destination: manageSubscriptionsURL)
            }
            .font(.caption2.weight(.medium))
            .tint(.white.opacity(0.6))
        }
        .padding(.top, 8)
    }
}

// MARK: - Notification Center View

struct NotificationCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Environment(AuthManager.self) private var authManager
    @State private var notifications: [CloudKitManager.NotificationItem] = []
    @State private var isLoading = true
    @State private var showClearAllConfirm = false
    @State private var isClearingAll = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if notifications.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 56))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("No notifications")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.85))
                        Text("You're all caught up!")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
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
                    .refreshable {
                        await loadNotifications()
                    }
                }

                if isClearingAll {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        Text("Clearing notifications...")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
                        .disabled(isClearingAll)
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
                Text("This will permanently delete all \(notifications.count) notifications from your family. This cannot be undone.")
            }
            .task {
                await loadNotifications()
            }
        }
    }

    private func loadNotifications() async {
        isLoading = notifications.isEmpty
        let result = await cloudKitManager.fetchNotifications(familyCode: authManager.familyCode)
        notifications = result.notifications
        isLoading = false
    }

    private func deleteNotifications(at offsets: IndexSet) {
        let toDelete = offsets.map { notifications[$0] }
        withAnimation {
            notifications.remove(atOffsets: offsets)
        }
        Task {
            for notif in toDelete {
                _ = await cloudKitManager.deleteNotification(id: notif.id)
            }
        }
    }

    private func clearAllNotifications() {
        isClearingAll = true
        let familyCode = authManager.familyCode
        Task {
            _ = await cloudKitManager.deleteAllNotifications(familyCode: familyCode)
            withAnimation {
                notifications.removeAll()
            }
            isClearingAll = false
        }
    }

    private func notificationRow(_ notif: CloudKitManager.NotificationItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: notif.senderAvatar.isEmpty ? "star.fill" : notif.senderAvatar)
                    .font(.title)
                    .foregroundStyle(colorForCategory(notif.category))
                    .frame(width: 36, height: 36)
                    .background(colorForCategory(notif.category).opacity(0.15), in: Circle())

                Image(systemName: iconForCategory(notif.category))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 16, height: 16)
                    .background(colorForCategory(notif.category), in: Circle())
                    .offset(x: 2, y: 2)
            }
            .frame(width: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(notif.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(notif.body)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(3)

                Text(notif.createdAt, format: .relative(presentation: .named))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()
        }
        .padding(14)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
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

#Preview {
    ContentView()
        .modelContainer(for: [Item.self, FamilyMember.self, RewardRedemption.self], inMemory: true)
        .environment(AuthManager())
        .environment(NotificationManager())
        .environment(SubscriptionManager())
        .environment(CloudKitManager())
}
