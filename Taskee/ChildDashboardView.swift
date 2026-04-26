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
    @Query(sort: \Item.targetDate) private var allTasks: [Item]
    @Query private var allMembers: [FamilyMember]
    @State private var showOpenOnly = false
    @State private var showAddTask = false
    @State private var showCelebration = false
    @State private var celebrationReward: Double = 0
    @State private var celebrationTitle = ""
    @State private var celebrationSubtitle = ""
    @State private var taskToComplete: Item?

    private var myTasks: [Item] {
        let assigned = allTasks.filter { $0.assignedTo == authManager.userName && !$0.isArchived }
        return showOpenOnly ? assigned.filter { $0.isOpen } : assigned
    }

    private var totalEarned: Double {
        allTasks
            .filter { $0.assignedTo == authManager.userName && $0.isApproved }
            .reduce(0) { $0 + $1.reward }
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
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationTitle("\(authManager.userName)'s Tasks")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    filterToggle
                }
                ToolbarItem(placement: .navigationBarTrailing) {
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
            .onAppear {
                archiveOldTasks()
            }
        }
    }

    private func archiveOldTasks() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        for task in allTasks where task.isApproved && !task.isArchived && task.targetDate < cutoff {
            task.isArchived = true
        }
    }

    private func completeTask(_ task: Item) {
        if task.createdByChild {
            withAnimation(.snappy) {
                task.status = "approved"
            }
            celebrationTitle = "Task Complete!"
            celebrationSubtitle = ""
        } else {
            withAnimation(.snappy) {
                task.status = "inReview"
            }
            notificationManager.sendTaskReviewNotification(
                taskName: task.name,
                childName: authManager.userName
            )
            celebrationTitle = "Submitted for Review!"
            celebrationSubtitle = "Waiting for parent approval"
        }
        SoundManager.shared.playApplause()
        celebrationReward = task.reward
        showCelebration = true
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
        .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
    }

    private var earningsCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total Earned")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))

                Text("$\(totalEarned, specifier: "%.2f")")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
            }

            Spacer()

            Image(systemName: "star.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.yellow.opacity(0.7))
        }
        .padding(18)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.green.opacity(0.2), lineWidth: 1)
        )
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
            Image(systemName: showOpenOnly ? "checkmark.circle" : "tray")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.3))
            Text(showOpenOnly ? "All done!" : "No tasks yet")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.7))
            Text(showOpenOnly ? "You've completed all your tasks." : "Your parent hasn't assigned any tasks yet.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    }

    private var statusIcon: (Item) -> String {{ task in
        if task.isApproved { return "checkmark.circle.fill" }
        if task.isInReview { return "clock.fill" }
        return "circle"
    }}

    private var statusColor: (Item) -> Color {{ task in
        if task.isApproved { return .green }
        if task.isInReview { return .orange }
        return .white.opacity(0.35)
    }}

    private func childTaskRow(task: Item) -> some View {
        HStack(spacing: 14) {
            Button {
                guard task.isOpen else { return }
                taskToComplete = task
            } label: {
                Image(systemName: statusIcon(task))
                    .font(.title3)
                    .foregroundStyle(statusColor(task))
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
                        .foregroundStyle(task.isApproved ? .green : .green.opacity(0.7))
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .opacity(task.isApproved ? 0.7 : 1)
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

// MARK: - Add Task View (Child)

struct AddChildTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(NotificationManager.self) private var notificationManager
    let childName: String
    let parents: [FamilyMember]

    @State private var taskName = ""
    @State private var targetDate = Date()
    @State private var assignedTo = ""
    @State private var recurrenceType: RecurrenceType = .none
    @State private var occurrences = 4
    @State private var selectedWeekdays: Set<Int> = []

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

                            TextField("What do you need to do?", text: $taskName)
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
                        let target = assignedTo.isEmpty ? childName : assignedTo
                        for date in dates {
                            let task = Item(
                                name: trimmedName,
                                targetDate: date,
                                assignedTo: target,
                                reward: 0,
                                createdByChild: true
                            )
                            modelContext.insert(task)
                            notificationManager.scheduleTaskReminder(
                                taskId: task.id,
                                taskName: trimmedName,
                                assignedTo: target,
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

    private func assignChip(name: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
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

#Preview {
    ChildDashboardView()
        .modelContainer(for: [Item.self, FamilyMember.self], inMemory: true)
        .environment(AuthManager())
        .environment(NotificationManager())
}
