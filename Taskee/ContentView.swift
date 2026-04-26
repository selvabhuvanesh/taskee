//
//  ContentView.swift
//  Taskee
//
//  Created by Selva Bhuvanesh on 4/25/26.
//

import SwiftUI
import SwiftData

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
            Image(systemName: avatar.isEmpty ? "person.circle.fill" : avatar)
                .font(.system(size: 32))
                .foregroundStyle(.blue)
                .frame(width: 44, height: 44)
                .background(.blue.opacity(0.15), in: Circle())
                .overlay(
                    Circle().strokeBorder(.blue.opacity(0.5), lineWidth: 2)
                )

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
    @Query(sort: \Item.targetDate) private var tasks: [Item]
    @Query private var allMembers: [FamilyMember]

    private var children: [FamilyMember] {
        var seen = Set<String>()
        return allMembers.filter { $0.isChild }.filter { seen.insert($0.name).inserted }
    }
    @State private var showingAddTask = false
    @State private var showingChildren = false
    @State private var showPendingApprovals = false
    @State private var showOpenOnly = false
    @State private var showCelebration = false
    @State private var celebrationReward: Double = 0

    private var activeTasks: [Item] {
        tasks.filter { !$0.isArchived }
    }

    private var myTasks: [Item] {
        activeTasks.filter { $0.assignedTo == authManager.userName || $0.assignedTo.isEmpty }
    }

    private var filteredTasks: [Item] {
        showOpenOnly ? myTasks.filter { !$0.isApproved } : myTasks
    }

    private var pendingReviewCount: Int {
        activeTasks.filter { $0.isInReview }.count
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

                    if filteredTasks.isEmpty {
                        emptyState
                    } else {
                        groupList
                    }

                    addTaskButton
                        .padding(.bottom, 16)
                }

                CelebrationOverlay(
                    isActive: $showCelebration,
                    title: "Task Approved!",
                    subtitle: "Reward credited",
                    rewardAmount: celebrationReward
                )
            }
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
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showingChildren = true
                        } label: {
                            Image(systemName: "person.2")
                                .font(.subheadline)
                        }

                        Menu {
                            Text(authManager.userName)
                            Text(authManager.phoneNumber)
                            Divider()
                            Button(role: .destructive) {
                                authManager.logout()
                            } label: {
                                Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        } label: {
                            Image(systemName: "person.circle")
                                .font(.title3)
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
            .onAppear {
                archiveOldTasks()
            }
        }
    }

    private func archiveOldTasks() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        for task in tasks where task.isApproved && !task.isArchived && task.targetDate < cutoff {
            task.isArchived = true
        }
    }

    private var childrenStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(children) { child in
                    NavigationLink(destination: ChildTasksView(
                        child: child,
                        tasks: activeTasks.filter { $0.assignedTo == child.name },
                        allChildren: children
                    )) {
                        VStack(spacing: 4) {
                            Image(systemName: child.avatar.isEmpty ? "person.circle.fill" : child.avatar)
                                .font(.system(size: 22))
                                .foregroundStyle(.yellow)
                                .frame(width: 40, height: 40)
                                .background(.yellow.opacity(0.2), in: Circle())
                                .overlay(
                                    Circle().strokeBorder(.yellow.opacity(0.5), lineWidth: 1.5)
                                )

                            Text(child.name)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                        .frame(width: 50)
                    }
                }
            }
            .padding(.trailing, 16)
            .padding(.vertical, 6)
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

    private var groupList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(groupedTasks, id: \.key) { group in
                    NavigationLink(destination: DateTasksView(
                        dateLabel: group.key,
                        tasks: group.tasks,
                        children: children,
                        onTaskCompleted: { reward in
                            celebrationReward = reward
                            showCelebration = true
                        }
                    )) {
                        GroupCard(dateLabel: group.key, count: group.tasks.count)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
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
        .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
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
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
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
    let dateLabel: String
    let tasks: [Item]
    let children: [FamilyMember]
    var onTaskCompleted: ((Double) -> Void)?
    @State private var taskToDelete: Item?
    @State private var taskToEdit: Item?
    @State private var taskToApprove: Item?

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(tasks) { task in
                        TaskRow(
                            task: task,
                            showAssignee: true,
                            onApprove: {
                                taskToApprove = task
                            },
                            onEdit: { taskToEdit = task },
                            onDelete: { taskToDelete = task }
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 2)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 12)
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationTitle(dateLabel)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Task", isPresented: Binding(
            get: { taskToDelete != nil },
            set: { if !$0 { taskToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                taskToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let task = taskToDelete {
                    notificationManager.cancelTaskReminder(taskId: task.id)
                    withAnimation {
                        modelContext.delete(task)
                    }
                    taskToDelete = nil
                }
            }
        } message: {
            if let task = taskToDelete {
                Text("Are you sure you want to delete \"\(task.name)\"?")
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
    }

    private func handleApproval(task: Item) {
        task.status = "approved"
        if task.reward > 0 && !task.assignedTo.isEmpty {
            if let child = children.first(where: { $0.name == task.assignedTo }) {
                child.totalEarned += task.reward
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
        onTaskCompleted?(task.reward)
    }
}

// MARK: - Child Tasks View

struct ChildTasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationManager.self) private var notificationManager
    let child: FamilyMember
    let tasks: [Item]
    let allChildren: [FamilyMember]
    @State private var showOpenOnly = false
    @State private var taskToEdit: Item?
    @State private var taskToDelete: Item?
    @State private var taskToApprove: Item?
    @State private var showCelebration = false
    @State private var celebrationReward: Double = 0

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
                                            onApprove: { taskToApprove = task },
                                            onEdit: { taskToEdit = task },
                                            onDelete: { taskToDelete = task }
                                        )
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 2)
                                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .strokeBorder(
                                                    task.isInReview ? .orange.opacity(0.3) : .white.opacity(0.08),
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
            }

            CelebrationOverlay(
                isActive: $showCelebration,
                title: "Task Approved!",
                subtitle: "Reward credited",
                rewardAmount: celebrationReward
            )
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
        .alert("Delete Task", isPresented: Binding(
            get: { taskToDelete != nil },
            set: { if !$0 { taskToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { taskToDelete = nil }
            Button("Delete", role: .destructive) {
                if let task = taskToDelete {
                    notificationManager.cancelTaskReminder(taskId: task.id)
                    withAnimation { modelContext.delete(task) }
                    taskToDelete = nil
                }
            }
        } message: {
            if let task = taskToDelete {
                Text("Are you sure you want to delete \"\(task.name)\"?")
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
                    if task.reward > 0 {
                        child.totalEarned += task.reward
                    }
                    notificationManager.sendTaskApprovedNotification(
                        taskName: task.name,
                        childName: child.name,
                        reward: task.reward
                    )
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
    }

    private var childHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: child.avatar.isEmpty ? "person.circle.fill" : child.avatar)
                .font(.system(size: 36))
                .foregroundStyle(.blue)
                .frame(width: 52, height: 52)
                .background(.blue.opacity(0.15), in: Circle())
                .overlay(
                    Circle().strokeBorder(.blue.opacity(0.5), lineWidth: 2)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(child.name)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Earned: $\(child.totalEarned, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundStyle(.green.opacity(0.85))
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
    }
}

// MARK: - Task Row

struct TaskRow: View {
    @Bindable var task: Item
    var showAssignee: Bool = false
    var onApprove: (() -> Void)?
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    private var statusIcon: String {
        if task.isApproved { return "checkmark.circle.fill" }
        if task.isInReview { return "clock.fill" }
        return "circle"
    }

    private var statusColor: Color {
        if task.isApproved { return .green }
        if task.isInReview { return .orange }
        return .white.opacity(0.35)
    }

    var body: some View {
        HStack(spacing: 14) {
            Button {
                guard task.isOpen || task.isInReview else { return }
                if task.isInReview || task.assignedTo.isEmpty || task.createdByChild {
                    onApprove?()
                }
            } label: {
                Image(systemName: statusIcon)
                    .font(.title3)
                    .foregroundStyle(statusColor)
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
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))

                    if task.reward > 0 {
                        Text("•")
                            .foregroundStyle(.white.opacity(0.3))
                        Label(
                            task.isApproved ? "Earned $\(task.reward, specifier: "%.2f")" : "$\(task.reward, specifier: "%.2f")",
                            systemImage: "dollarsign.circle.fill"
                        )
                        .font(.caption.weight(.medium))
                        .foregroundStyle(task.isApproved ? .green : .green.opacity(0.85))
                    }

                    if showAssignee && !task.assignedTo.isEmpty {
                        Text("•")
                            .foregroundStyle(.white.opacity(0.3))
                        Label(task.assignedTo, systemImage: "person.fill")
                            .font(.caption)
                            .foregroundStyle(.blue.opacity(0.8))
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
                            Image(systemName: "pencil.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.blue.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }

                    if let onDelete {
                        Button {
                            onDelete()
                        } label: {
                            Image(systemName: "trash.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.red.opacity(0.6))
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
            .tint(.blue)
        }
    }
}

// MARK: - Recurrence

enum RecurrenceType: String, CaseIterable {
    case none = "None"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
}

let weekdayLabels = ["S", "M", "T", "W", "T", "F", "S"]

// MARK: - Add Task View (Parent)

struct AddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(NotificationManager.self) private var notificationManager
    let children: [FamilyMember]

    @State private var taskName = ""
    @State private var targetDate = Date()
    @State private var selectedChild = ""
    @State private var rewardText = ""
    @State private var recurrenceType: RecurrenceType = .none
    @State private var occurrences = 4
    @State private var selectedWeekdays: Set<Int> = []

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
                                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
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
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                            )
                        }

                        recurrenceSection

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reward ($)")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))

                            HStack(spacing: 10) {
                                Image(systemName: "dollarsign.circle.fill")
                                    .foregroundStyle(.green)

                                TextField("0.00", text: $rewardText)
                                    .font(.body)
                                    .foregroundStyle(.white)
                                    .keyboardType(.decimalPad)
                            }
                            .padding(14)
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
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
                                    childChip(name: "Unassigned", isSelected: selectedChild.isEmpty) {
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
                        let dates = generateTaskDates()
                        let trimmedName = taskName.trimmingCharacters(in: .whitespaces)
                        for date in dates {
                            let task = Item(
                                name: trimmedName,
                                targetDate: date,
                                assignedTo: selectedChild,
                                reward: rewardValue
                            )
                            modelContext.insert(task)
                            notificationManager.scheduleTaskReminder(
                                taskId: task.id,
                                taskName: trimmedName,
                                assignedTo: selectedChild,
                                dueDate: date
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
                if newValue == .weekly && selectedWeekdays.isEmpty {
                    let weekday = Calendar.current.component(.weekday, from: targetDate)
                    selectedWeekdays.insert(weekday)
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
                                        selectedWeekdays.contains(day) ? .blue : .white.opacity(0.08),
                                        in: Circle()
                                    )
                                    .foregroundStyle(selectedWeekdays.contains(day) ? .white : .white.opacity(0.5))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                Stepper(value: $occurrences, in: 2...52) {
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
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
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
                    .foregroundStyle(isSelected ? .blue : .white.opacity(0.3))
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(12)
            .background(
                isSelected ? .blue.opacity(0.15) : .white.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isSelected ? .blue.opacity(0.4) : .white.opacity(0.08),
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
                                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
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
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                            )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reward ($)")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))

                            HStack(spacing: 10) {
                                Image(systemName: "dollarsign.circle.fill")
                                    .foregroundStyle(.green)

                                TextField("0.00", text: $rewardText)
                                    .font(.body)
                                    .foregroundStyle(.white)
                                    .keyboardType(.decimalPad)
                            }
                            .padding(14)
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
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
                                    editChildChip(name: "Unassigned", isSelected: selectedChild.isEmpty) {
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
                    .foregroundStyle(isSelected ? .blue : .white.opacity(0.3))
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(12)
            .background(
                isSelected ? .blue.opacity(0.15) : .white.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isSelected ? .blue.opacity(0.4) : .white.opacity(0.08),
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
    @Query private var allMembers: [FamilyMember]
    @State private var newChildName = ""
    @State private var memberToRemove: FamilyMember?

    private var parents: [FamilyMember] {
        var seen = Set<String>()
        return allMembers.filter { $0.isParent }.filter { seen.insert($0.name).inserted }
    }
    private var children: [FamilyMember] {
        var seen = Set<String>()
        return allMembers.filter { $0.isChild }.filter { seen.insert($0.name).inserted }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        inviteCodeSection

                        if !parents.isEmpty {
                            memberSection(title: "Parents (\(parents.count)/2)", members: parents, canRemove: false)
                        }

                        memberSection(title: "Children (\(children.count)/10)", members: children, canRemove: true)

                        if children.count < 10 {
                            addChildSection
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
                        modelContext.delete(member)
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

            Text("Share this code with family members to join")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.35))

            ShareLink(
                item: "Join my family on Taskee! Use invite code: \(authManager.familyCode)"
            ) {
                Label("Share Invite", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.blue, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
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
                        Image(systemName: member.avatar.isEmpty ? "person.circle.fill" : member.avatar)
                            .font(.title3)
                            .foregroundStyle(.blue)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.name)
                                .font(.body)
                                .foregroundStyle(.white)

                            if member.isChild {
                                Text("Earned: $\(member.totalEarned, specifier: "%.2f")")
                                    .font(.caption)
                                    .foregroundStyle(.green.opacity(0.8))
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
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                    )
                }
            }
        }
    }

    private var addChildSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add Child")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))

            HStack(spacing: 10) {
                TextField("Child's name", text: $newChildName)
                    .font(.body)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    )

                Button {
                    let child = FamilyMember(name: newChildName.trimmingCharacters(in: .whitespaces))
                    modelContext.insert(child)
                    newChildName = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .disabled(newChildName.trimmingCharacters(in: .whitespaces).isEmpty || children.count >= 10)
            }
        }
    }
}

// MARK: - Pending Approvals View

struct PendingApprovalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(NotificationManager.self) private var notificationManager
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
                        withAnimation(.snappy) {
                            task.status = "approved"
                            if task.reward > 0 && !task.assignedTo.isEmpty {
                                if let child = children.first(where: { $0.name == task.assignedTo }) {
                                    child.totalEarned += task.reward
                                }
                            }
                            onApproved?(task.reward)
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
                                .foregroundStyle(.blue.opacity(0.8))
                        }

                        Text(task.dueDateLabel)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.45))

                        if task.reward > 0 {
                            Text("•")
                                .foregroundStyle(.white.opacity(0.3))
                            Label("$\(task.reward, specifier: "%.2f")", systemImage: "dollarsign.circle.fill")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.green.opacity(0.85))
                        }
                    }
                }

                Spacer()
            }

            HStack(spacing: 10) {
                Button {
                    withAnimation(.snappy) {
                        task.status = "open"
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
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
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
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 52))
                                .foregroundStyle(.blue)

                            Text("Set Up Your Family")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)

                            Text("Add your children and share the invite code so other family members can join.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                        }

                        inviteCodeCard

                        if !children.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Children (\(children.count)/10)")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))

                                ForEach(children) { child in
                                    HStack {
                                        Image(systemName: child.avatar.isEmpty ? "person.circle.fill" : child.avatar)
                                            .font(.title3)
                                            .foregroundStyle(.blue)
                                            .frame(width: 32)

                                        Text(child.name)
                                            .font(.body)
                                            .foregroundStyle(.white)

                                        Spacer()
                                    }
                                    .padding(14)
                                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                                    )
                                }
                            }
                        }

                        if children.count < 10 {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Add Child")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))

                                HStack(spacing: 10) {
                                    TextField("Child's name", text: $newChildName)
                                        .font(.body)
                                        .foregroundStyle(.white)
                                        .padding(12)
                                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                                        )

                                    Button {
                                        let child = FamilyMember(name: newChildName.trimmingCharacters(in: .whitespaces))
                                        modelContext.insert(child)
                                        newChildName = ""
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(.blue)
                                    }
                                    .disabled(newChildName.trimmingCharacters(in: .whitespaces).isEmpty || children.count >= 10)
                                }
                            }
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
            Text("Family Invite Code")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))

            Text(authManager.familyCode)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .tracking(6)

            Text("Share this code with family members to join")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.35))

            ShareLink(
                item: "Join my family on Taskee! Use invite code: \(authManager.familyCode)"
            ) {
                Label("Share Invite", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.blue, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Item.self, FamilyMember.self], inMemory: true)
        .environment(AuthManager())
        .environment(NotificationManager())
}
