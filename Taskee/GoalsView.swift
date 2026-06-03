//
//  GoalsView.swift
//  Taskee
//

import SwiftUI
import SwiftData

// MARK: - Goals Tab Content (inline on home page)

struct GoalsTabContent: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Goal.createdAt) private var goals: [Goal]
    @Query(sort: \Item.targetDate) private var allTasks: [Item]

    let userName: String
    let audience: GoalAudience
    let theme: ChildTheme
    @Binding var showGoalPicker: Bool

    private var myGoals: [Goal] { goals.filter { $0.assignedTo == userName } }
    private var activeGoals: [Goal] { myGoals.filter { $0.isActive } }
    private var completedGoals: [Goal] { myGoals.filter { $0.isCompleted } }

    @State private var selectedGoal: Goal?
    @State private var goalToDelete: Goal?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if myGoals.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "target")
                            .font(.system(size: 44))
                            .foregroundStyle(theme.secondaryTextColor)
                        Text("No goals yet")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(theme.textColor)
                        Text("Pick a goal and we'll create a plan with tasks, schedule, and rewards to help you achieve it.")
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryTextColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Button { showGoalPicker = true } label: {
                            Text("Set a Goal")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 10)
                                .background(.teal, in: Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    if !activeGoals.isEmpty {
                        HStack {
                            Text("Active")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(theme.textColor)
                            Spacer()
                            Button { showGoalPicker = true } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add Goal")
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.textColor.opacity(0.7))
                            }
                        }

                        ForEach(activeGoals) { goal in
                            GoalProgressCard(goal: goal, tasks: allTasks, theme: theme)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedGoal = goal }
                                .contextMenu {
                                    Button { selectedGoal = goal } label: {
                                        Label("View Details", systemImage: "info.circle")
                                    }
                                    Button(role: .destructive) { goalToDelete = goal } label: {
                                        Label("Delete Goal", systemImage: "trash")
                                    }
                                }
                        }
                    }

                    if !completedGoals.isEmpty {
                        Text("Completed")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(theme.secondaryTextColor)
                            .padding(.top, 8)

                        ForEach(completedGoals) { goal in
                            GoalProgressCard(goal: goal, tasks: allTasks, theme: theme)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedGoal = goal }
                                .contextMenu {
                                    Button { selectedGoal = goal } label: {
                                        Label("View Details", systemImage: "info.circle")
                                    }
                                    Button(role: .destructive) { goalToDelete = goal } label: {
                                        Label("Delete Goal", systemImage: "trash")
                                    }
                                }
                        }
                    }

                    if activeGoals.isEmpty {
                        Button { showGoalPicker = true } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add a new goal")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.teal)
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 60)
        }
        .sheet(item: $selectedGoal) { goal in
            GoalDetailView(goal: goal, theme: theme)
        }
        .alert("Delete Goal?", isPresented: Binding(
            get: { goalToDelete != nil },
            set: { if !$0 { goalToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let goal = goalToDelete {
                    let openTasks = allTasks.filter { $0.goalId == goal.id.uuidString && $0.isOpen }
                    for task in openTasks { modelContext.delete(task) }
                    modelContext.delete(goal)
                    try? modelContext.save()
                }
                goalToDelete = nil
            }
            Button("Cancel", role: .cancel) { goalToDelete = nil }
        } message: {
            if let goal = goalToDelete {
                let openCount = allTasks.filter { $0.goalId == goal.id.uuidString && $0.isOpen }.count
                Text("This will delete \"\(goal.name)\" and its \(openCount) open task\(openCount == 1 ? "" : "s"). Completed tasks are kept.")
            }
        }
    }
}

// MARK: - Goals Dashboard (shown on home page)

struct GoalsDashboardView: View {
    let goals: [Goal]
    let tasks: [Item]
    let theme: ChildTheme
    let onAddGoal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Goals")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(theme.textColor)
                Spacer()
                Button(action: onAddGoal) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Goal")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textColor.opacity(0.7))
                }
            }

            if goals.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "target")
                        .font(.system(size: 32))
                        .foregroundStyle(theme.secondaryTextColor)
                    Text("No goals yet")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.secondaryTextColor)
                    Text("Set a goal and we'll help you plan the tasks to achieve it")
                        .font(.caption)
                        .foregroundStyle(theme.tertiaryTextColor)
                        .multilineTextAlignment(.center)
                    Button(action: onAddGoal) {
                        Text("Set a Goal")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(.blue, in: Capsule())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(goals.filter { $0.isActive }) { goal in
                    GoalProgressCard(goal: goal, tasks: tasks, theme: theme)
                }
            }
        }
    }
}

// MARK: - Goal Progress Card

struct GoalProgressCard: View {
    let goal: Goal
    let tasks: [Item]
    let theme: ChildTheme

    private var progress: Double { goal.progress(from: tasks) }
    private var done: Int { goal.tasksDone(from: tasks) }
    private var total: Int { goal.totalTasks(from: tasks) }
    private var category: GoalCategory { GoalCategory(rawValue: goal.category) ?? .lifestyle }

    private var dialColor: Color { progress >= 1.0 ? .green : .teal }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: goal.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(dialColor)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(goal.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textColor)
                Text("\(done)/\(total) tasks done")
                    .font(.caption2)
                    .foregroundStyle(theme.secondaryTextColor)
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(dialColor.opacity(0.18), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(dialColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(dialColor)
            }
            .frame(width: 46, height: 46)
        }
        .padding(12)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Goal Picker Sheet

struct GoalPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Query(sort: \Item.targetDate) private var allTasks: [Item]

    let audience: GoalAudience
    let assignee: String
    let theme: ChildTheme

    @State private var selectedTemplate: GoalTemplate?
    @State private var showCustomGoal = false
    @State private var customGoalName = ""
    @State private var customCategory: GoalCategory = .lifestyle
    @State private var showTaskPreview = false
    @State private var editableTasks: [EditableSuggestedTask] = []
    @State private var goalDuration: Int = 30

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: theme.gradientColors, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(GoalTemplateCatalog.grouped(for: audience), id: \.category) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: group.category.icon)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(group.category.color)
                                Text(group.category.rawValue)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(theme.textColor)
                            }
                            .padding(.horizontal, 4)

                            ForEach(group.templates) { template in
                                Button {
                                    selectedTemplate = template
                                    goalDuration = template.durationDays
                                    editableTasks = template.suggestedTasks.map { EditableSuggestedTask(from: $0) }
                                    showTaskPreview = true
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: template.icon)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(group.category.color)
                                            .frame(width: 36, height: 36)
                                            .background(group.category.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(template.name)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(theme.textColor)
                                            Text("\(template.suggestedTasks.count) tasks \u{00B7} \(template.durationDays) days")
                                                .font(.caption2)
                                                .foregroundStyle(theme.secondaryTextColor)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.caption2)
                                            .foregroundStyle(theme.tertiaryTextColor)
                                    }
                                    .padding(12)
                                    .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }

                    // Custom goal option
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkle")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.indigo)
                            Text("Custom Goal")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(theme.textColor)
                        }
                        .padding(.horizontal, 4)

                        Button { showCustomGoal = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.indigo)
                                    .frame(width: 36, height: 36)
                                    .background(.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                                Text("Create your own goal")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(theme.textColor)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(theme.tertiaryTextColor)
                            }
                            .padding(12)
                            .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(16)
            }
            }
            .navigationTitle("Choose a Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showTaskPreview) {
                if let template = selectedTemplate {
                    GoalTaskPreviewView(
                        goalName: template.name,
                        goalIcon: template.icon,
                        category: template.category,
                        templateId: template.id,
                        isCustom: false,
                        assignee: assignee,
                        durationDays: $goalDuration,
                        editableTasks: $editableTasks,
                        theme: theme,
                        onConfirm: { createGoalWithTasks(name: template.name, icon: template.icon, category: template.category, templateId: template.id, isCustom: false) }
                    )
                }
            }
            .sheet(isPresented: $showCustomGoal) {
                CustomGoalView(
                    assignee: assignee,
                    theme: theme,
                    onCreate: { name, category, tasks, duration in
                        editableTasks = tasks
                        goalDuration = duration
                        createGoalWithTasks(name: name, icon: category.icon, category: category, templateId: "", isCustom: true)
                    }
                )
            }
        }
    }

    private func createGoalWithTasks(name: String, icon: String, category: GoalCategory, templateId: String, isCustom: Bool) {
        let goal = Goal(
            name: name,
            category: category.rawValue,
            icon: icon,
            assignedTo: assignee,
            createdBy: authManager.userName,
            targetDate: Calendar.current.date(byAdding: .day, value: goalDuration, to: Date()) ?? Date(),
            isCustom: isCustom,
            templateId: templateId
        )
        modelContext.insert(goal)

        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        let familyCode = authManager.familyCode
        var createdItems: [Item] = []

        for task in editableTasks where task.isEnabled {
            let baseDate = calendar.date(bySettingHour: task.hour, minute: task.minute, second: 0, of: startDate) ?? startDate
            let isRecurring = task.frequency != .none
            let dates = generateDates(start: baseDate, frequency: task.frequency, count: task.occurrences)

            for date in dates {
                let item = Item(
                    name: task.name,
                    targetDate: date,
                    assignedTo: assignee,
                    reward: Double(task.reward),
                    isRecurring: isRecurring,
                    createdBy: authManager.userName,
                    createdByID: authManager.appleUserID,
                    goalId: goal.id.uuidString
                )
                modelContext.insert(item)
                createdItems.append(item)
                notificationManager.scheduleTaskReminder(taskId: item.id, taskName: item.name, assignedTo: assignee, dueDate: date)
            }
        }

        try? modelContext.save()

        Task {
            for item in createdItems {
                await cloudKitManager.pushTask(item, familyCode: familyCode)
            }
        }

        showTaskPreview = false
        showCustomGoal = false
        dismiss()
    }

    private func generateDates(start: Date, frequency: RecurrenceType, count: Int) -> [Date] {
        let calendar = Calendar.current
        switch frequency {
        case .none: return [start]
        case .daily: return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        case .weekly: return (0..<count).compactMap { calendar.date(byAdding: .weekOfYear, value: $0, to: start) }
        case .monthly: return (0..<count).compactMap { calendar.date(byAdding: .month, value: $0, to: start) }
        }
    }
}

// MARK: - Editable Suggested Task

struct EditableSuggestedTask: Identifiable {
    let id = UUID()
    var name: String
    var frequency: RecurrenceType
    var occurrences: Int
    var reward: Int
    var hour: Int
    var minute: Int
    var isEnabled: Bool = true

    init(from suggested: SuggestedTask) {
        self.name = suggested.name
        self.frequency = suggested.frequency
        self.occurrences = suggested.occurrences
        self.reward = suggested.reward
        self.hour = suggested.hour
        self.minute = suggested.minute
    }

    init(name: String = "", frequency: RecurrenceType = .daily, occurrences: Int = 7, reward: Int = 2, hour: Int = 9, minute: Int = 0) {
        self.name = name
        self.frequency = frequency
        self.occurrences = occurrences
        self.reward = reward
        self.hour = hour
        self.minute = minute
    }
}

// MARK: - Task Preview & Edit View

struct GoalTaskPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let goalName: String
    let goalIcon: String
    let category: GoalCategory
    let templateId: String
    let isCustom: Bool
    let assignee: String
    @Binding var durationDays: Int
    @Binding var editableTasks: [EditableSuggestedTask]
    let theme: ChildTheme
    let onConfirm: () -> Void

    private var totalTaskCount: Int {
        editableTasks.filter { $0.isEnabled }.reduce(0) { $0 + $1.occurrences }
    }

    private var totalCoins: Int {
        editableTasks.filter { $0.isEnabled }.reduce(0) { $0 + ($1.reward * $1.occurrences) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: theme.gradientColors, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Goal header
                    HStack(spacing: 12) {
                        Image(systemName: goalIcon)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(category.color)
                            .frame(width: 48, height: 48)
                            .background(category.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(goalName)
                                .font(.title3.weight(.bold))
                            Text("For \(assignee) \u{00B7} \(durationDays) days")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.bottom, 4)

                    // Summary
                    HStack(spacing: 16) {
                        statBadge(value: "\(totalTaskCount)", label: "Tasks", icon: "checklist")
                        statBadge(value: "\(totalCoins)", label: "Coins", icon: "star.circle.fill")
                        statBadge(value: "\(durationDays)d", label: "Duration", icon: "calendar")
                    }

                    Divider()

                    Text("Tasks to Create")
                        .font(.subheadline.weight(.bold))

                    ForEach($editableTasks) { $task in
                        taskEditRow(task: $task)
                    }

                    Button {
                        editableTasks.append(EditableSuggestedTask())
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Task")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.blue)
                    }
                    .padding(.top, 4)
                }
                .padding(16)
            }
            }
            .navigationTitle("Preview Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create \(totalTaskCount) Tasks") { onConfirm() }
                        .font(.subheadline.weight(.semibold))
                        .disabled(editableTasks.filter { $0.isEnabled && !$0.name.isEmpty }.isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private func taskEditRow(task: Binding<EditableSuggestedTask>) -> some View {
        VStack(spacing: 8) {
            HStack {
                Toggle("", isOn: task.isEnabled)
                    .labelsHidden()
                    .scaleEffect(0.8)

                TextField("Task name", text: task.name)
                    .font(.subheadline)
                    .disabled(!task.wrappedValue.isEnabled)
                    .opacity(task.wrappedValue.isEnabled ? 1 : 0.4)

                Spacer()

                Button(role: .destructive) {
                    editableTasks.removeAll { $0.id == task.wrappedValue.id }
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.6))
                }
            }

            if task.wrappedValue.isEnabled {
                HStack(spacing: 12) {
                    Picker("", selection: task.frequency) {
                        ForEach(RecurrenceType.allCases, id: \.self) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.caption)

                    HStack(spacing: 4) {
                        Text("x")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        TextField("", value: task.occurrences, format: .number)
                            .font(.caption)
                            .frame(width: 40)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        TextField("", value: task.reward, format: .number)
                            .font(.caption)
                            .frame(width: 35)
                            .textFieldStyle(.roundedBorder)
                    }

                    DatePicker("", selection: Binding(
                        get: {
                            Calendar.current.date(bySettingHour: task.wrappedValue.hour, minute: task.wrappedValue.minute, second: 0, of: Date()) ?? Date()
                        },
                        set: { newDate in
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                            task.wrappedValue.hour = comps.hour ?? 9
                            task.wrappedValue.minute = comps.minute ?? 0
                        }
                    ), displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .font(.caption)
                }
                .padding(.leading, 36)
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }

    private func statBadge(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(category.color)
            Text(value)
                .font(.subheadline.weight(.bold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(category.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Custom Goal View

struct CustomGoalView: View {
    @Environment(\.dismiss) private var dismiss
    let assignee: String
    let theme: ChildTheme
    let onCreate: (String, GoalCategory, [EditableSuggestedTask], Int) -> Void

    @State private var goalName = ""
    @State private var category: GoalCategory = .lifestyle
    @State private var durationDays = 30
    @State private var tasks: [EditableSuggestedTask] = [EditableSuggestedTask()]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: theme.gradientColors, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Goal Name")
                            .font(.subheadline.weight(.semibold))
                        TextField("e.g., Learn to swim", text: $goalName)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Category")
                            .font(.subheadline.weight(.semibold))
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                            ForEach(GoalCategory.allCases) { cat in
                                Button {
                                    category = cat
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: cat.icon)
                                            .font(.caption)
                                        Text(cat.rawValue)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity)
                                    .background(category == cat ? cat.color.opacity(0.2) : Color.primary.opacity(0.05), in: Capsule())
                                    .overlay(Capsule().strokeBorder(category == cat ? cat.color : .clear, lineWidth: 1.5))
                                    .foregroundStyle(category == cat ? cat.color : .primary.opacity(0.6))
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Duration")
                            .font(.subheadline.weight(.semibold))
                        Picker("", selection: $durationDays) {
                            Text("2 weeks").tag(14)
                            Text("1 month").tag(30)
                            Text("2 months").tag(60)
                            Text("3 months").tag(90)
                        }
                        .pickerStyle(.segmented)
                    }

                    Divider()

                    Text("Tasks")
                        .font(.subheadline.weight(.bold))

                    ForEach($tasks) { $task in
                        VStack(spacing: 6) {
                            TextField("Task name", text: $task.name)
                                .font(.subheadline)
                                .textFieldStyle(.roundedBorder)
                            HStack(spacing: 12) {
                                Picker("", selection: $task.frequency) {
                                    ForEach(RecurrenceType.allCases, id: \.self) { freq in
                                        Text(freq.rawValue).tag(freq)
                                    }
                                }
                                .pickerStyle(.menu)
                                .font(.caption)

                                HStack(spacing: 4) {
                                    Text("x")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    TextField("", value: $task.occurrences, format: .number)
                                        .font(.caption)
                                        .frame(width: 40)
                                        .textFieldStyle(.roundedBorder)
                                }

                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                    TextField("", value: $task.reward, format: .number)
                                        .font(.caption)
                                        .frame(width: 35)
                                        .textFieldStyle(.roundedBorder)
                                }

                                Button(role: .destructive) {
                                    tasks.removeAll { $0.id == task.id }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundStyle(.red.opacity(0.6))
                                }
                            }
                        }
                        .padding(10)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                    }

                    Button {
                        tasks.append(EditableSuggestedTask())
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Task")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.blue)
                    }
                }
                .padding(16)
            }
            }
            .navigationTitle("Custom Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(goalName, category, tasks, durationDays)
                        dismiss()
                    }
                    .disabled(goalName.isEmpty || tasks.filter { !$0.name.isEmpty }.isEmpty)
                }
            }
        }
    }
}

// MARK: - Full Goals List View

struct GoalsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Goal.createdAt) private var goals: [Goal]
    @Query(sort: \Item.targetDate) private var allTasks: [Item]
    @Environment(AuthManager.self) private var authManager

    let userName: String
    let audience: GoalAudience
    let theme: ChildTheme

    @State private var showGoalPicker = false
    @State private var selectedGoal: Goal?
    @State private var goalToDelete: Goal?

    private var myGoals: [Goal] {
        goals.filter { $0.assignedTo == userName }
    }

    private var activeGoals: [Goal] {
        myGoals.filter { $0.isActive }
    }

    private var completedGoals: [Goal] {
        myGoals.filter { $0.isCompleted }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if activeGoals.isEmpty && completedGoals.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "target")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        Text("No goals yet")
                            .font(.title3.weight(.semibold))
                        Text("Pick a goal and we'll create a plan with tasks, schedule, and rewards to help you achieve it.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Button {
                            showGoalPicker = true
                        } label: {
                            Text("Set a Goal")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 10)
                                .background(.blue, in: Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    if !activeGoals.isEmpty {
                        Text("Active Goals")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(theme.textColor)
                            .padding(.horizontal, 4)

                        ForEach(activeGoals) { goal in
                            GoalProgressCard(goal: goal, tasks: allTasks, theme: theme)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedGoal = goal }
                                .contextMenu {
                                    Button { selectedGoal = goal } label: {
                                        Label("View Details", systemImage: "info.circle")
                                    }
                                    Button(role: .destructive) { goalToDelete = goal } label: {
                                        Label("Delete Goal", systemImage: "trash")
                                    }
                                }
                        }
                    }

                    if !completedGoals.isEmpty {
                        Text("Completed")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(theme.secondaryTextColor)
                            .padding(.horizontal, 4)
                            .padding(.top, 8)

                        ForEach(completedGoals) { goal in
                            GoalProgressCard(goal: goal, tasks: allTasks, theme: theme)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedGoal = goal }
                                .contextMenu {
                                    Button { selectedGoal = goal } label: {
                                        Label("View Details", systemImage: "info.circle")
                                    }
                                    Button(role: .destructive) { goalToDelete = goal } label: {
                                        Label("Delete Goal", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Goals")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showGoalPicker = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showGoalPicker) {
            GoalPickerView(audience: audience, assignee: userName, theme: theme)
        }
        .sheet(item: $selectedGoal) { goal in
            GoalDetailView(goal: goal, theme: theme)
        }
        .alert("Delete Goal?", isPresented: Binding(
            get: { goalToDelete != nil },
            set: { if !$0 { goalToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let goal = goalToDelete {
                    let openTasks = allTasks.filter { $0.goalId == goal.id.uuidString && $0.isOpen }
                    for task in openTasks { modelContext.delete(task) }
                    modelContext.delete(goal)
                    try? modelContext.save()
                }
                goalToDelete = nil
            }
            Button("Cancel", role: .cancel) { goalToDelete = nil }
        } message: {
            if let goal = goalToDelete {
                let openCount = allTasks.filter { $0.goalId == goal.id.uuidString && $0.isOpen }.count
                Text("This will delete \"\(goal.name)\" and its \(openCount) open task\(openCount == 1 ? "" : "s"). Completed tasks are kept.")
            }
        }
    }
}

// MARK: - Task Edit Draft

struct TaskEditDraft {
    var name: String
    var targetDate: Date
    var reward: Double
}

// MARK: - Goal Detail View

struct GoalDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Item.targetDate) private var allTasks: [Item]

    let goal: Goal
    let theme: ChildTheme

    @State private var isEditing = false
    @State private var editName: String = ""
    @State private var editCategory: GoalCategory = .lifestyle
    @State private var editTargetDate: Date = Date()
    @State private var showDeleteConfirm = false
    @State private var taskToDelete: Item?
    @State private var isEditingTasks = false
    @State private var taskEdits: [UUID: TaskEditDraft] = [:]

    private var goalTasks: [Item] {
        allTasks.filter { $0.goalId == goal.id.uuidString }
    }

    private var doneTasks: [Item] {
        goalTasks.filter { $0.isApproved }
    }

    private var openTasks: [Item] {
        goalTasks.filter { $0.isOpen || $0.isInReview }
    }

    private var progress: Double { goal.progress(from: allTasks) }
    private var category: GoalCategory { GoalCategory(rawValue: goal.category) ?? .lifestyle }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: theme.gradientColors, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack(spacing: 12) {
                        Image(systemName: goal.icon)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(category.color)
                            .frame(width: 52, height: 52)
                            .background(category.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 4) {
                            if isEditing {
                                TextField("Goal name", text: $editName)
                                    .font(.title3.weight(.bold))
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                Text(goal.name)
                                    .font(.title3.weight(.bold))
                            }
                            Text("\(goal.assignedTo) \u{00B7} \(category.rawValue)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Menu {
                            Button {
                                editName = goal.name
                                editCategory = GoalCategory(rawValue: goal.category) ?? .lifestyle
                                editTargetDate = goal.targetDate
                                withAnimation { isEditing = true }
                            } label: {
                                Label("Edit Goal", systemImage: "pencil")
                            }
                            if goal.isActive {
                                Button { goal.status = "paused"; try? modelContext.save() } label: {
                                    Label("Pause", systemImage: "pause.circle")
                                }
                                Button { goal.status = "completed"; try? modelContext.save() } label: {
                                    Label("Mark Complete", systemImage: "checkmark.circle")
                                }
                            } else if goal.isPaused {
                                Button { goal.status = "active"; try? modelContext.save() } label: {
                                    Label("Resume", systemImage: "play.circle")
                                }
                            }
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Label("Delete Goal", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if isEditing {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Category")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 6) {
                                ForEach(GoalCategory.allCases) { cat in
                                    Button {
                                        editCategory = cat
                                    } label: {
                                        HStack(spacing: 3) {
                                            Image(systemName: cat.icon)
                                                .font(.caption2)
                                            Text(cat.rawValue)
                                                .font(.caption2)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .frame(maxWidth: .infinity)
                                        .background(editCategory == cat ? cat.color.opacity(0.2) : Color.primary.opacity(0.05), in: Capsule())
                                        .overlay(Capsule().strokeBorder(editCategory == cat ? cat.color : .clear, lineWidth: 1.5))
                                        .foregroundStyle(editCategory == cat ? cat.color : .primary.opacity(0.6))
                                    }
                                }
                            }

                            Text("Target Date")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            DatePicker("", selection: $editTargetDate, displayedComponents: .date)
                                .labelsHidden()

                            HStack(spacing: 12) {
                                Button {
                                    goal.name = editName
                                    goal.category = editCategory.rawValue
                                    goal.icon = editCategory.icon
                                    goal.targetDate = editTargetDate
                                    try? modelContext.save()
                                    withAnimation { isEditing = false }
                                } label: {
                                    Text("Save")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 8)
                                        .background(.teal, in: Capsule())
                                }
                                .disabled(editName.trimmingCharacters(in: .whitespaces).isEmpty)

                                Button {
                                    withAnimation { isEditing = false }
                                } label: {
                                    Text("Cancel")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(12)
                        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                    }

                    // Progress
                    VStack(spacing: 8) {
                        ProgressView(value: progress)
                            .tint(progress >= 1.0 ? .green : category.color)
                            .scaleEffect(y: 1.5)
                        HStack {
                            Text("\(doneTasks.count)/\(goalTasks.count) tasks done")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(progress * 100))%")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(progress >= 1.0 ? .green : category.color)
                        }
                    }
                    .padding(.vertical, 4)

                    Divider()

                    // Open tasks
                    if !openTasks.isEmpty {
                        HStack {
                            Text("Upcoming (\(openTasks.count))")
                                .font(.subheadline.weight(.bold))
                            Spacer()
                            if isEditingTasks {
                                Button {
                                    saveAllTaskEdits()
                                    withAnimation { isEditingTasks = false }
                                } label: {
                                    Text("Save All")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 5)
                                        .background(.teal, in: Capsule())
                                }
                                Button {
                                    taskEdits.removeAll()
                                    withAnimation { isEditingTasks = false }
                                } label: {
                                    Text("Cancel")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Button {
                                    beginEditingAllTasks()
                                    withAnimation { isEditingTasks = true }
                                } label: {
                                    HStack(spacing: 3) {
                                        Image(systemName: "pencil")
                                            .font(.caption2)
                                        Text("Edit All")
                                            .font(.caption.weight(.semibold))
                                    }
                                    .foregroundStyle(category.color)
                                }
                            }
                        }

                        ForEach(openTasks.prefix(20)) { task in
                            if isEditingTasks {
                                editableTaskRow(task: task)
                            } else {
                                goalTaskRow(task: task, completed: false)
                            }
                        }
                    }

                    // Completed tasks
                    if !doneTasks.isEmpty {
                        Text("Completed (\(doneTasks.count))")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                        ForEach(doneTasks.prefix(10)) { task in
                            goalTaskRow(task: task, completed: true)
                        }
                    }
                }
                .padding(16)
            }
            }
            .navigationTitle("Goal Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete Goal?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    for task in goalTasks where task.isOpen {
                        modelContext.delete(task)
                    }
                    modelContext.delete(goal)
                    try? modelContext.save()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete \"\(goal.name)\" and its \(openTasks.count) open task\(openTasks.count == 1 ? "" : "s"). Completed tasks are kept.")
            }
            .alert("Delete Task?", isPresented: Binding(
                get: { taskToDelete != nil },
                set: { if !$0 { taskToDelete = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let task = taskToDelete {
                        modelContext.delete(task)
                        try? modelContext.save()
                    }
                    taskToDelete = nil
                }
                Button("Cancel", role: .cancel) { taskToDelete = nil }
            } message: {
                if let task = taskToDelete {
                    Text("Are you sure you want to delete \"\(task.name)\"?")
                }
            }
        }
    }

    @ViewBuilder
    private func goalTaskRow(task: Item, completed: Bool) -> some View {
        HStack(spacing: 8) {
            if completed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.green)
                Text(task.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .strikethrough()
            } else {
                Text(task.emoji)
                    .font(.system(size: 14))
                VStack(alignment: .leading, spacing: 1) {
                    Text(task.name)
                        .font(.subheadline)
                    Text(task.targetDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !completed && task.reward > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                    Text("\(Int(task.reward))")
                        .font(.caption2.weight(.semibold))
                }
            }
            if task.isOpen {
                Button(role: .destructive) {
                    taskToDelete = task
                } label: {
                    Image(systemName: "trash")
                        .font(.caption2)
                        .foregroundStyle(.red.opacity(0.5))
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func editableTaskRow(task: Item) -> some View {
        let draft = Binding<TaskEditDraft>(
            get: { taskEdits[task.id] ?? TaskEditDraft(name: task.name, targetDate: task.targetDate, reward: task.reward) },
            set: { taskEdits[task.id] = $0 }
        )
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                TextField("Task name", text: draft.name)
                    .font(.subheadline)
                    .textFieldStyle(.roundedBorder)
                Button(role: .destructive) { taskToDelete = task } label: {
                    Image(systemName: "trash")
                        .font(.caption2)
                        .foregroundStyle(.red.opacity(0.5))
                }
            }
            HStack(spacing: 10) {
                DatePicker("", selection: draft.targetDate)
                    .labelsHidden()
                    .font(.caption)
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    TextField("", value: draft.reward, format: .number)
                        .font(.caption)
                        .frame(width: 40)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }

    private func beginEditingAllTasks() {
        taskEdits.removeAll()
        for task in openTasks {
            taskEdits[task.id] = TaskEditDraft(name: task.name, targetDate: task.targetDate, reward: task.reward)
        }
    }

    private func saveAllTaskEdits() {
        for task in openTasks {
            guard let draft = taskEdits[task.id] else { continue }
            task.name = draft.name
            task.targetDate = draft.targetDate
            task.reward = draft.reward
        }
        try? modelContext.save()
        taskEdits.removeAll()
    }
}
