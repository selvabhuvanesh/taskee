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
    @State private var pickupPosition: CGPoint = .zero
    @State private var pickupInitialized = false
    @State private var showNotificationCenter = false
    @State private var showRedeemSheet = false
    @State private var showRewardsHistory = false
    @State private var showEditProfile = false
    @State private var showShareSheet = false
    @State private var stickyNote: (message: String, color: Color)?
    @State private var taskToDelete: Item?
    @State private var flyingCoins: [FlyingCoin] = []
    @State private var earningsCardCenter: CGPoint = .zero
    @State private var lastCompletedTaskCenter: CGPoint = .zero
    @State private var coinLandBounce = false
    @Query private var allRedemptions: [RewardRedemption]

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
        myRedemptions.filter { $0.isApproved || $0.isFulfilled || $0.isPending }.reduce(0) { $0 + $1.coinAmount }
    }

    private var totalEarnedCoins: Int {
        allTasks
            .filter { $0.assignedTo == authManager.userName && $0.isApproved && $0.reward > 0 }
            .reduce(0) { $0 + Int($1.reward) }
    }

    private var collectableCoins: Int {
        max(0, totalEarnedCoins - redeemedCoins)
    }

    private var todayOpenCount: Int {
        allTasks.filter {
            $0.assignedTo == authManager.userName && $0.isOpen && !$0.isArchived
            && Calendar.current.isDateInToday($0.targetDate)
        }.count
    }

    private var myTasks: [Item] {
        let assigned = allTasks.filter { $0.assignedTo == authManager.userName && !$0.isArchived }
        return showAll ? assigned : assigned.filter { !$0.isApproved }
    }

    private var groupedTasks: [(key: String, tasks: [Item])] {
        let grouped = Dictionary(grouping: myTasks) { $0.dueDateLabel }
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
                    UserAvatarHeader(name: authManager.userName, avatar: authManager.avatar)
                        .padding(.top, 4)

                    earningsCard
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
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

                    if myTasks.isEmpty {
                        emptyState
                    } else {
                        taskList
                    }

                    addTaskButton
                        .padding(.bottom, 16)
                }

                CelebrationOverlay(
                    isActive: $showCelebration,
                    title: celebrationTitle,
                    subtitle: celebrationSubtitle,
                    rewardAmount: 0
                )

                FlyingCoinsOverlay(coins: $flyingCoins)

                pickupFloatingButton

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
            .coordinateSpace(name: "childDashboard")
            .onAppear { scheduleStickyNote(from: childTips) }
            .toolbarColorScheme(.dark, for: .navigationBar)
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
                                    if todayOpenCount > 0 {
                                        Text("\(todayOpenCount)")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.white)
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
                                Label("Edit Profile", systemImage: "pencil.circle")
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
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [childShareMessage, appStoreURL])
            }
            .sheet(isPresented: $showNotificationCenter) {
                NotificationCenterView()
            }
            .sheet(isPresented: $showRedeemSheet) {
                RedeemRewardsView(availableCoins: collectableCoins, childName: authManager.userName)
            }
            .sheet(isPresented: $showRewardsHistory) {
                RewardsHistoryView(redemptions: myRedemptions)
            }
            .sheet(isPresented: $showAddTask) {
                AddChildTaskView(
                    childName: authManager.userName,
                    parents: {
                        var seen = Set<String>()
                        return allMembers.filter { $0.isParent }.filter { seen.insert($0.name).inserted }
                    }()
                )
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
            .alert("Delete Task?", isPresented: Binding(
                get: { taskToDelete != nil },
                set: { if !$0 { taskToDelete = nil } }
            )) {
                if let task = taskToDelete {
                    if task.isRecurring {
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
                    if task.isRecurring {
                        let count = allTasks.filter {
                            $0.name == task.name && $0.assignedTo == task.assignedTo
                            && $0.createdByChild && $0.isOpen && $0.isRecurring && !$0.isArchived
                        }.count
                        Text("\"\(task.name)\" is a recurring task with \(count) open instances. Delete just this one or all of them?")
                    } else {
                        Text("Are you sure you want to delete \"\(task.name)\"?")
                    }
                }
            }
            .task {
                archiveOldTasks()
            }
        }
    }

    private func archiveOldTasks() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let toArchive = allTasks.filter { $0.isApproved && !$0.isArchived && $0.targetDate < cutoff }
        guard !toArchive.isEmpty else { return }
        for task in toArchive {
            task.isArchived = true
        }
    }

    private func deleteTask(_ task: Item) {
        notificationManager.cancelTaskReminder(taskId: task.id)
        let taskId = task.id
        modelContext.delete(task)
        Task {
            await cloudKitManager.deleteRemoteTask(taskId)
        }
    }

    private func deleteAllRecurring(like task: Item) {
        let matching = allTasks.filter {
            $0.name == task.name && $0.assignedTo == task.assignedTo
            && $0.createdByChild && $0.isOpen && $0.isRecurring && !$0.isArchived
        }
        var taskIDs: [UUID] = []
        for t in matching {
            notificationManager.cancelTaskReminder(taskId: t.id)
            taskIDs.append(t.id)
            modelContext.delete(t)
        }
        Task { await cloudKitManager.deleteRemoteTasks(taskIDs) }
    }

    private func completeTask(_ task: Item) {
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
            let taskName = task.name
            let childName = authManager.userName
            Task {
                await cloudKitManager.sendRemoteNotification(
                    familyCode: authManager.familyCode,
                    title: "Task Submitted for Review",
                    body: "\(childName) completed \"\(taskName)\"",
                    category: "TASK_REVIEW",
                    senderAvatar: authManager.avatar
                )
            }
            celebrationTitle = "Submitted for Review!"
            celebrationSubtitle = "Waiting for parent approval"
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

    private var pickupFloatingButton: some View {
        GeometryReader { geo in
            Button {
                guard subscriptionManager.canSendPickup() else {
                    showPickupLimit = true
                    return
                }
                subscriptionManager.recordPickup()
                Task {
                    await cloudKitManager.sendRemoteNotification(
                        familyCode: authManager.familyCode,
                        title: "Pickup Request!",
                        body: "\(authManager.userName) wants to be picked up in 5 minutes!",
                        category: "PICKUP_REQUEST",
                        senderAvatar: authManager.avatar
                    )
                }
                showPickupSent = true
            } label: {
                ZStack {
                    Image(systemName: "car.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: -2, y: -4)
                    Image(systemName: "clock.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.yellow)
                        .offset(x: 14, y: 10)
                }
                .frame(width: 64, height: 64)
                .background(calmAccent, in: Circle())
                .shadow(color: calmAccent.opacity(0.5), radius: 10, y: 4)
            }
            .position(pickupPosition)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        pickupPosition = clampPosition(
                            CGPoint(x: value.location.x, y: value.location.y),
                            in: geo.size
                        )
                    }
                    .onEnded { _ in
                        UserDefaults.standard.set(Float(pickupPosition.x), forKey: "pickupButtonX")
                        UserDefaults.standard.set(Float(pickupPosition.y), forKey: "pickupButtonY")
                    }
            )
            .onAppear {
                guard !pickupInitialized else { return }
                pickupInitialized = true
                let savedX = UserDefaults.standard.float(forKey: "pickupButtonX")
                let savedY = UserDefaults.standard.float(forKey: "pickupButtonY")
                if savedX != 0 || savedY != 0 {
                    pickupPosition = CGPoint(x: CGFloat(savedX), y: CGFloat(savedY))
                } else {
                    pickupPosition = CGPoint(
                        x: geo.size.width - 52,
                        y: geo.size.height - 90
                    )
                }
            }
        }
        .allowsHitTesting(true)
    }

    private func clampPosition(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 40), size.width - 40),
            y: min(max(point.y, 40), size.height - 40)
        )
    }

    private var addTaskButton: some View {
        Button {
            showAddTask = true
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

    private var earningsCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Image(systemName: "star.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                    Text("\(collectableCoins)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                        .contentTransition(.numericText())
                    Text("Ready to Redeem")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 1, height: 50)

                VStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                        .scaleEffect(coinLandBounce ? 1.3 : 1.0)
                    Text("\(awaitingApprovalCoins)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                        .scaleEffect(coinLandBounce ? 1.3 : 1.0)
                        .contentTransition(.numericText())
                    Text("Awaiting Approval")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
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
                        if collectableCoins > 0 {
                            Text("\(collectableCoins)")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.white.opacity(0.2), in: Capsule())
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(collectableCoins > 0 ? .orange : .white.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                }
                .disabled(collectableCoins <= 0)

                Button {
                    showRewardsHistory = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption)
                        Text("History")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(18)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
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
                    .foregroundStyle(.white.opacity(0.3))
                Text(showAll ? "No tasks yet" : "All done!")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
                Text(showAll ? "Your parent hasn't assigned any tasks yet." : "You've completed all your active tasks.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.4))
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

    private var taskList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(groupedTasks, id: \.key) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.key)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.leading, 4)

                        ForEach(group.tasks) { task in
                            childTaskRow(task: task)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
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

    private func statusColor(for task: Item) -> Color {
        if task.isApproved { return .green }
        if task.isInReview { return .orange }
        return .white.opacity(0.4)
    }

    private func statusLabel(for task: Item) -> String {
        if task.isApproved { return "Done" }
        if task.isInReview { return "Review" }
        return "To Do"
    }

    private func childTaskRow(task: Item) -> some View {
        HStack(spacing: 14) {
            Button {
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
                    Text(statusLabel(for: task))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .disabled(!task.isOpen)

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
                }
            }

            Spacer()

            if task.createdByChild && task.isOpen {
                Button {
                    taskToDelete = task
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.red.opacity(0.7), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .opacity(task.isApproved ? 0.7 : 1)
        .background(.white.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    task.isInReview ? .orange.opacity(0.3) : .white.opacity(0.25),
                    lineWidth: 1
                )
        )
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

    @State private var taskName = ""
    @State private var targetDate = Date()
    @State private var assignedTo = ""
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
                            VStack(spacing: 6) {
                                HStack(spacing: 8) {
                                    Image(systemName: remaining == 0 ? "xmark.circle.fill" : remaining <= 10 ? "exclamationmark.triangle.fill" : "info.circle.fill")
                                        .foregroundStyle(remaining == 0 ? .red : remaining <= 10 ? .orange : .cyan)
                                    Text(remaining == 0 ? "Task limit reached" : "\(remaining) tasks remaining this month")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.white.opacity(0.85))
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
                            Text("Task Name")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))

                            TextField("What do you need to do?", text: $taskName)
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

                        if !parents.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Assign To")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))

                                VStack(spacing: 8) {
                                    assignChip(name: "Myself", isSelected: assignedTo.isEmpty) {
                                        assignedTo = ""
                                    }

                                    ForEach(parents) { parent in
                                        assignChip(name: parent.name, isSelected: assignedTo == parent.name) {
                                            assignedTo = parent.name
                                        }
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
            .toolbarColorScheme(.dark, for: .navigationBar)
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
                                isRecurring: recurring
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
                        let senderName = childName
                        let taskCount = createdTasks.count
                        Task {
                            for task in createdTasks {
                                await cloudKitManager.pushTask(task, familyCode: familyCode)
                            }
                            await cloudKitManager.sendRemoteNotification(
                                familyCode: familyCode,
                                title: "New Task Created",
                                body: "\(senderName) created \"\(trimmedName)\"" + (taskCount > 1 ? " (\(taskCount) tasks)" : ""),
                                category: "TASK_CREATED",
                                senderAvatar: authManager.avatar
                            )
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

    private var childRecurrenceSection: some View {
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

                TextField("e.g. Read a book tomorrow 4pm daily", text: $smartInput, axis: .vertical)
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
                        smartRow(icon: "person.fill", label: "Assign To", value: parsed.assignedTo.isEmpty ? childName : parsed.assignedTo)
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

// MARK: - Redeem Rewards View

struct RedeemRewardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Environment(AuthManager.self) private var authManager
    let availableCoins: Int
    let childName: String

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
                AppBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 12)

                        VStack(spacing: 8) {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.yellow)

                            Text("\(availableCoins) coins available")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)

                            Text("Choose how you'd like to use your coins!")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("What would you like?")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))

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
                                            selectedType == type.0 ? .orange.opacity(0.2) : .white.opacity(0.1),
                                            in: RoundedRectangle(cornerRadius: 10)
                                        )
                                        .foregroundStyle(selectedType == type.0 ? .orange : .white.opacity(0.6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(
                                                    selectedType == type.0 ? .orange.opacity(0.5) : .white.opacity(0.1),
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
                                .foregroundStyle(.white.opacity(0.7))

                            HStack(spacing: 10) {
                                Image(systemName: "star.circle.fill")
                                    .foregroundStyle(.yellow)

                                TextField("0", text: $coinAmount)
                                    .font(.body)
                                    .foregroundStyle(.white)
                                    .keyboardType(.numberPad)

                                Spacer()

                                Button("Use all") {
                                    coinAmount = "\(availableCoins)"
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                            }
                            .padding(14)
                            .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
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
                                .foregroundStyle(.white.opacity(0.7))

                            TextField("e.g., LEGO Star Wars set", text: $description)
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
                            await cloudKitManager.sendRemoteNotification(
                                familyCode: familyCode,
                                title: "Reward Request!",
                                body: "\(childName) wants to redeem \(amount) coins for: \(description.trimmingCharacters(in: .whitespaces))",
                                category: "REWARD_REQUEST",
                                senderAvatar: authManager.avatar
                            )
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

// MARK: - Rewards History View

struct RewardsHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Environment(AuthManager.self) private var authManager
    let redemptions: [RewardRedemption]
    var isParent: Bool = false
    @State private var confirmFulfill: RewardRedemption?

    private var sorted: [RewardRedemption] {
        redemptions.sorted { $0.createdAt > $1.createdAt }
    }

    private var awaitingAcknowledgement: [RewardRedemption] {
        sorted.filter { $0.isApproved }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                if sorted.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "gift")
                            .font(.system(size: 56))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("No rewards yet")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.85))
                        Text(isParent ? "No reward requests from children yet." : "Complete tasks and redeem your coins!")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            if isParent && !awaitingAcknowledgement.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .foregroundStyle(calmAccent)
                                        Text("Pending Acknowledgement (\(awaitingAcknowledgement.count))")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(calmAccent)
                                    }
                                    .padding(.horizontal, 4)

                                    ForEach(awaitingAcknowledgement) { redemption in
                                        redemptionRow(redemption)
                                    }
                                }
                                .padding(.bottom, 8)

                                if sorted.count > awaitingAcknowledgement.count {
                                    Text("All Requests")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white.opacity(0.7))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 4)
                                }
                            }

                            ForEach(isParent ? sorted.filter { !$0.isApproved } : sorted) { redemption in
                                redemptionRow(redemption)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                }
            }
            .navigationTitle("Rewards History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
                        let desc = r.itemDescription
                        let childName = r.childName
                        Task {
                            _ = await cloudKitManager.pushRedemption(r, familyCode: familyCode)
                            await cloudKitManager.sendRemoteNotification(
                                familyCode: familyCode,
                                title: "Reward Received",
                                body: "\(childName) confirmed receiving: \"\(desc)\"",
                                category: "REWARD_FULFILLED",
                                senderAvatar: authManager.avatar
                            )
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

    private func redemptionRow(_ r: RewardRedemption) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: r.typeIcon)
                    .font(.title3)
                    .foregroundStyle(statusColor(r))
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(r.itemDescription)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    HStack(spacing: 6) {
                        if isParent {
                            Label(r.childName, systemImage: "person.fill")
                                .font(.caption)
                                .foregroundStyle(calmAccent.opacity(0.8))

                            Text("•")
                                .foregroundStyle(.white.opacity(0.5))
                        }

                        Label("\(r.coinAmount) coins", systemImage: "star.circle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.yellow.opacity(0.85))

                        Text("•")
                            .foregroundStyle(.white.opacity(0.5))

                        Text(r.typeLabel)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    HStack(spacing: 6) {
                        statusBadge(r)

                        Text(r.createdAt, format: .relative(presentation: .named))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.55))
                    }

                    if r.isRejected && !r.rejectReason.isEmpty {
                        Text("Reason: \(r.rejectReason)")
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                }

                Spacer()
            }

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
                    .foregroundStyle(.white)
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
        .padding(14)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(statusColor(r).opacity(0.2), lineWidth: 1)
        )
    }

    private func statusBadge(_ r: RewardRedemption) -> some View {
        let label = r.isFulfilled ? "Closed" : r.status.capitalized
        return Text(label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(statusColor(r))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusColor(r).opacity(0.15), in: Capsule())
    }

    private func statusColor(_ r: RewardRedemption) -> Color {
        if r.isFulfilled { return .green }
        if r.isApproved { return calmAccent }
        if r.isRejected { return .red }
        return .orange
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

#Preview {
    ChildDashboardView()
        .modelContainer(for: [Item.self, FamilyMember.self, RewardRedemption.self], inMemory: true)
        .environment(AuthManager())
        .environment(NotificationManager())
        .environment(SubscriptionManager())
        .environment(CloudKitManager())
}
