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
    var onDone: (() -> Void)? = nil

    private var myGoals: [Goal] { goals.filter { $0.assignedTo == userName } }
    private var activeGoals: [Goal] { myGoals.filter { $0.isActive } }
    private var completedGoals: [Goal] { myGoals.filter { $0.isCompleted } }
    private var familyGoals: [Goal] { goals.filter { $0.assignedTo != userName } }
    private var familyActiveGoals: [Goal] { familyGoals.filter { $0.isActive } }
    private var familyCompletedGoals: [Goal] { familyGoals.filter { $0.isCompleted } }

    @State private var selectedGoal: Goal?
    @State private var goalToDelete: Goal?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let onDone {
                    HStack {
                        Spacer()
                        Button(action: onDone) {
                            Text("Done")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 7)
                                .background(theme.accentColor, in: Capsule())
                        }
                    }
                }

                if myGoals.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "target")
                            .font(.system(size: 44))
                            .foregroundStyle(theme.secondaryTextColor)
                        Text("No goals yet")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(theme.textColor)
                        Text("Tap 'Add Goal' to pick a goal and create a plan with tasks, schedule, and rewards.")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(theme.secondaryTextColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    if !activeGoals.isEmpty {
                        Text("Active")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(theme.textColor)

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

                }

                // Family Goals (parent view)
                if audience == .parent && !familyGoals.isEmpty {
                    Divider()
                        .padding(.vertical, 4)

                    Text("Family Goals")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(theme.textColor)
                        .padding(.top, 4)

                    if !familyActiveGoals.isEmpty {
                        ForEach(familyActiveGoals) { goal in
                            GoalProgressCard(goal: goal, tasks: allTasks, theme: theme)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedGoal = goal }
                                .contextMenu {
                                    Button { selectedGoal = goal } label: {
                                        Label("View Details", systemImage: "info.circle")
                                    }
                                    Button { selectedGoal = goal } label: {
                                        Label("Edit Goal", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) { goalToDelete = goal } label: {
                                        Label("Delete Goal", systemImage: "trash")
                                    }
                                }
                        }
                    }

                    if !familyCompletedGoals.isEmpty {
                        Text("Completed")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(theme.secondaryTextColor)
                            .padding(.top, 8)

                        ForEach(familyCompletedGoals) { goal in
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
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
        .safeAreaInset(edge: .bottom) {
            Button { showGoalPicker = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Goal")
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(theme.accentColor, in: Capsule())
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 100)
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
                    Text("Tap 'Add Goal' to get started")
                        .font(.caption)
                        .foregroundStyle(theme.tertiaryTextColor)
                        .multilineTextAlignment(.center)
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

    @State private var animatedProgress: Double = 0

    private var progress: Double { goal.progress(from: tasks) }
    private var done: Int { goal.tasksDone(from: tasks) }
    private var total: Int { goal.totalTasks(from: tasks) }
    private var category: GoalCategory { GoalCategory(rawValue: goal.category) ?? .lifestyle }

    private var dialColor: Color { animatedProgress >= 1.0 ? .green : .teal }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: goal.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(dialColor)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(goal.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.textColor)
                HStack(spacing: 4) {
                    Text(goal.assignedTo)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(category.color.opacity(0.8))
                    Text("·")
                        .foregroundStyle(theme.tertiaryTextColor)
                    Text("\(done)/\(total) tasks done")
                        .foregroundStyle(theme.secondaryTextColor)
                }
                .font(.caption2)
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(dialColor.opacity(0.18), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(dialColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(animatedProgress * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(dialColor)
            }
            .frame(width: 46, height: 46)
        }
        .padding(12)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
        .onAppear {
            animatedProgress = 0
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                animatedProgress = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation(.easeInOut(duration: 0.8)) {
                    animatedProgress = progress
                }
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeOut(duration: 0.4)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Mini Goal Dial (for avatar strip)

struct MiniGoalDial: View {
    let goal: Goal
    let tasks: [Item]
    let theme: ChildTheme
    let animationDelay: Double

    @State private var animatedProgress: Double = 0

    private var targetProgress: Double { goal.progress(from: tasks) }
    private var category: GoalCategory { GoalCategory(rawValue: goal.category) ?? .lifestyle }
    private var dialColor: Color { targetProgress >= 1.0 ? .green : category.color }

    private var shortName: String {
        let name = goal.name
        if name.count <= 8 { return name }
        // Take first word, truncate if too long
        let firstWord = String(name.prefix(while: { $0 != " " }))
        if firstWord.count <= 8 { return firstWord }
        return String(firstWord.prefix(7)) + "…"
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .stroke(dialColor.opacity(0.3), lineWidth: 4.5)
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(dialColor, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: dialColor.opacity(0.6), radius: 3, x: 0, y: 0)
                Text("\(Int(animatedProgress * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(dialColor)
            }
            .frame(width: 46, height: 46)
            Text(shortName)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(theme.secondaryTextColor)
                .lineLimit(1)
        }
        .onAppear {
            // Animate to 100% first, then settle back to actual progress
            animatedProgress = 0
            let stagger = animationDelay >= 0 ? animationDelay : 0
            withAnimation(.easeOut(duration: 0.6).delay(stagger)) {
                animatedProgress = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + stagger + 0.7) {
                withAnimation(.easeInOut(duration: 0.8)) {
                    animatedProgress = targetProgress
                }
            }
        }
        .onChange(of: targetProgress) { _, newValue in
            withAnimation(.easeOut(duration: 0.4)) {
                animatedProgress = newValue
            }
        }
    }
}

struct MemberGoalStrip: View {
    let memberName: String
    let goals: [Goal]
    let tasks: [Item]
    let theme: ChildTheme
    let onAddGoal: () -> Void
    let onTapGoal: (Goal) -> Void

    private var activeGoals: [Goal] {
        goals.filter { $0.assignedTo == memberName && ($0.isActive || $0.isPendingApproval) }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("Goal\nMeter")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.accentColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize()
            

                ForEach(Array(activeGoals.enumerated()), id: \.element.id) { index, goal in
                    Button { onTapGoal(goal) } label: {
                        MiniGoalDial(
                            goal: goal,
                            tasks: tasks,
                            theme: theme,
                            animationDelay: 0.3 + Double(index) * 0.15
                        )
                    }
                    .buttonStyle(.plain)
                }
                Button(action: onAddGoal) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(theme.accentColor)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().strokeBorder(theme.accentColor.opacity(0.3), lineWidth: 1.5))
                }
            }
            .padding(.vertical, 4)
        }
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

    enum Phase { case input, generating, review, refining }

    @State private var phase: Phase = .input
    @State private var goalName = ""
    @State private var goalDuration: Int = 30
    @State private var showTaskPreview = false
    @State private var editableTasks: [EditableSuggestedTask] = []
    @State private var aiCategory: GoalCategory = .lifestyle
    @State private var aiIcon: String = "star.fill"
    @State private var generationError: String?
    @State private var refinementText = ""
    @State private var currentTasks: [GoalTaskEntry] = []
    @State private var sparkleRotation: Double = 0
    @State private var sparkleScale: CGFloat = 0.5
    @State private var showTaskChoiceDialog = false
    @FocusState private var isInputFocused: Bool
    @FocusState private var isRefineFocused: Bool

    private var exampleGoals: [GoalTemplate] {
        GoalTemplateCatalog.templates(for: audience)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: theme.gradientColors, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        switch phase {
                        case .input:
                            inputPhase
                                .transition(.opacity)
                        case .generating:
                            generatingPhase
                                .transition(.opacity)
                        case .review, .refining:
                            reviewPhase
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .animation(.easeInOut(duration: 0.4), value: phase)
                    .padding(16)
                }
            }
            .navigationTitle("Add Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if phase == .review || phase == .refining {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation { phase = .input }
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.subheadline.weight(.bold))
                        }
                    }
                }
            }
            .sheet(isPresented: $showTaskPreview) {
                GoalTaskPreviewView(
                    goalName: goalName,
                    goalIcon: aiIcon,
                    category: aiCategory,
                    templateId: "",
                    isCustom: true,
                    assignee: assignee,
                    durationDays: $goalDuration,
                    editableTasks: $editableTasks,
                    theme: theme,
                    onConfirm: { createGoalWithTasks(name: goalName, icon: aiIcon, category: aiCategory, templateId: "", isCustom: true) }
                )
            }
        }
    }

    // MARK: - Phase 1: Input

    private var inputPhase: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("What do you want to achieve?")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.textColor)

                TextField("e.g., Learn to cook, Run a 5K...", text: $goalName)
                    .font(.body)
                    .padding(12)
                    .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(theme.accentColor.opacity(goalName.isEmpty ? 0 : 0.5), lineWidth: 1.5)
                    )
                    .focused($isInputFocused)
                    .submitLabel(.go)
                    .onSubmit { if !goalName.trimmingCharacters(in: .whitespaces).isEmpty { startGeneration() } }
            }

            // Duration picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Duration")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.secondaryTextColor)
                Picker("", selection: $goalDuration) {
                    Text("2 weeks").tag(14)
                    Text("1 month").tag(30)
                    Text("2 months").tag(60)
                    Text("3 months").tag(90)
                }
                .pickerStyle(.segmented)
            }

            // Generate button
            Button { startGeneration() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("Generate My Plan")
                        .font(.body.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    goalName.trimmingCharacters(in: .whitespaces).isEmpty
                        ? theme.accentColor.opacity(0.4) : theme.accentColor,
                    in: RoundedRectangle(cornerRadius: 12)
                )
            }
            .disabled(goalName.trimmingCharacters(in: .whitespaces).isEmpty)

            Divider().overlay(theme.tertiaryTextColor)

            // Example chips
            VStack(alignment: .leading, spacing: 10) {
                Text("Ideas for you")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.secondaryTextColor)

                FlowLayout(spacing: 8) {
                    ForEach(exampleGoals) { template in
                        Button {
                            goalName = template.name
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: template.icon)
                                    .font(.caption2)
                                Text(template.name)
                                    .font(.caption)
                            }
                            .foregroundStyle(goalName == template.name ? .white : theme.textColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                goalName == template.name ? theme.accentColor : theme.cardBackground,
                                in: Capsule()
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Phase 2: Generating (animation)

    private var generatingPhase: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 60)

            ZStack {
                // Outer rotating ring
                Circle()
                    .stroke(theme.accentColor.opacity(0.2), lineWidth: 3)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(theme.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(sparkleRotation))

                // Center sparkle icon
                Image(systemName: "sparkles")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(theme.accentColor)
                    .scaleEffect(sparkleScale)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    sparkleRotation = 360
                }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    sparkleScale = 1.1
                }
            }

            Text("Creating your plan...")
                .font(.headline)
                .foregroundStyle(theme.textColor)

            Text("\"\(goalName)\"")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(theme.secondaryTextColor)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 60)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Phase 3 & 4: Review / Refine

    private var reviewPhase: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Goal header
            HStack(spacing: 10) {
                Image(systemName: aiIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(aiCategory.color)
                    .frame(width: 40, height: 40)
                    .background(aiCategory.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(goalName)
                        .font(.headline)
                        .foregroundStyle(theme.textColor)
                    Text("\(goalDuration) days \u{00B7} \(aiCategory.rawValue)")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryTextColor)
                }
                Spacer()
            }

            // AI message
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(theme.accentColor)
                    .padding(.top, 2)
                Text("Here's a plan to help you achieve your goal. You can refine it or go ahead!")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.secondaryTextColor)
            }

            // Error
            if let error = generationError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryTextColor)
                    Spacer()
                    Button("Retry") { startGeneration() }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.accentColor)
                }
                .padding(10)
                .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
            }

            // Task list
            VStack(spacing: 8) {
                ForEach(Array(currentTasks.enumerated()), id: \.offset) { index, task in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(aiCategory.color)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(theme.textColor)
                            HStack(spacing: 8) {
                                Label(task.frequency.rawValue, systemImage: "repeat")
                                Label("x\(task.occurrences)", systemImage: "number")
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(.orange)
                                    Text("\(task.reward)")
                                }
                            }
                            .font(.caption2)
                            .foregroundStyle(theme.tertiaryTextColor)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity).animation(.spring(duration: 0.4).delay(Double(index) * 0.08)),
                        removal: .opacity
                    ))
                }
            }

            // Refinement input
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    TextField("Ask AI to adjust tasks...", text: $refinementText)
                        .font(.subheadline.weight(.bold))
                        .padding(10)
                        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                        .focused($isRefineFocused)
                        .submitLabel(.send)
                        .onSubmit { if !refinementText.trimmingCharacters(in: .whitespaces).isEmpty { refineTaskList() } }

                    if phase == .refining {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button { refineTaskList() } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(refinementText.trimmingCharacters(in: .whitespaces).isEmpty ? theme.tertiaryTextColor : theme.accentColor)
                        }
                        .disabled(refinementText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        editableTasks = currentTasks.map { EditableSuggestedTask(from: $0) }
                        if assignee != authManager.userName {
                            showTaskChoiceDialog = true
                        } else {
                            showTaskPreview = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                            Text("Looks Good")
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(theme.accentColor, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .confirmationDialog("How should tasks be created?", isPresented: $showTaskChoiceDialog, titleVisibility: .visible) {
                    Button("Create tasks now") {
                        showTaskPreview = true
                    }
                    Button("Let \(assignee) plan tasks") {
                        createGoalOnly()
                    }
                    Button("Cancel", role: .cancel) { }
                }
            }
        }
    }

    // MARK: - Actions

    private func startGeneration() {
        let trimmedName = goalName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        isInputFocused = false
        generationError = nil
        sparkleRotation = 0
        sparkleScale = 0.5

        withAnimation { phase = .generating }

        let recentTasks = allTasks.filter { $0.assignedTo == assignee }
        let total = recentTasks.count
        let done = recentTasks.filter { $0.isApproved }.count
        let insightText = total > 5 ? "User has completed \(done)/\(total) tasks recently (\(Int(Double(done) / Double(total) * 100))% completion rate)." : ""

        Task {
            do {
                let suggestion = try await ClaudeAPIService.shared.generateGoalTasks(
                    goalName: trimmedName,
                    audience: audience,
                    durationDays: goalDuration,
                    memberInsight: insightText
                )

                // Brief delay so animation feels intentional
                try await Task.sleep(for: .seconds(1.2))

                await MainActor.run {
                    if suggestion.tasks.isEmpty {
                        generationError = "Couldn't generate tasks. Try a different goal or tap Retry."
                        withAnimation { phase = .input }
                    } else {
                        aiCategory = suggestion.category
                        aiIcon = suggestion.icon
                        currentTasks = suggestion.tasks
                        withAnimation(.spring(duration: 0.5)) { phase = .review }
                    }
                }
            } catch {
                await MainActor.run {
                    generationError = "Something went wrong. Check your connection and try again."
                    withAnimation { phase = .input }
                }
            }
        }
    }

    private func refineTaskList() {
        let feedback = refinementText.trimmingCharacters(in: .whitespaces)
        guard !feedback.isEmpty else { return }
        isRefineFocused = false

        withAnimation { phase = .refining }

        Task {
            do {
                let suggestion = try await ClaudeAPIService.shared.refineGoalTasks(
                    goalName: goalName.trimmingCharacters(in: .whitespaces),
                    audience: audience,
                    durationDays: goalDuration,
                    currentTasks: currentTasks,
                    userFeedback: feedback
                )

                await MainActor.run {
                    refinementText = ""
                    if !suggestion.tasks.isEmpty {
                        aiCategory = suggestion.category
                        aiIcon = suggestion.icon
                        withAnimation(.spring(duration: 0.5)) {
                            currentTasks = suggestion.tasks
                            phase = .review
                        }
                    } else {
                        generationError = "Couldn't refine tasks. Try again."
                        phase = .review
                    }
                }
            } catch {
                await MainActor.run {
                    generationError = "Refinement failed. Try again."
                    phase = .review
                }
            }
        }
    }

    private func createGoalOnly() {
        let goal = Goal(
            name: goalName,
            category: aiCategory.rawValue,
            icon: aiIcon,
            assignedTo: assignee,
            createdBy: authManager.userName,
            targetDate: Calendar.current.date(byAdding: .day, value: goalDuration, to: Date()) ?? Date(),
            isCustom: true,
            templateId: ""
        )
        if authManager.role == "child" {
            goal.status = "pendingApproval"
        }
        modelContext.insert(goal)
        try? modelContext.save()

        // Notify parent if child created this goal
        if authManager.role == "child" {
            notificationManager.sendGoalApprovalNotification(
                goalName: goalName,
                childName: authManager.userName
            )
        }
        dismiss()
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
        // If a child creates this goal, it needs parent approval before they can start
        if authManager.role == "child" {
            goal.status = "pendingApproval"
        }
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

        // Notify parent if child created this goal for plan review
        if authManager.role == "child" {
            notificationManager.sendGoalApprovalNotification(
                goalName: name,
                childName: authManager.userName
            )
        }

        Task {
            for item in createdItems {
                await cloudKitManager.pushTask(item, familyCode: familyCode)
            }
        }

        showTaskPreview = false
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

    init(from entry: GoalTaskEntry) {
        self.name = entry.name
        self.frequency = entry.frequency
        self.occurrences = entry.occurrences
        self.reward = entry.reward
        self.hour = entry.hour
        self.minute = entry.minute
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

                    ForEach(editableTasks) { task in
                        taskEditRow(task: editableTaskBinding(task.id))
                    }

                    Button {
                        editableTasks.append(EditableSuggestedTask())
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Task")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.accentColor)
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
                        .font(.subheadline.weight(.bold))
                        .disabled(editableTasks.filter { $0.isEnabled && !$0.name.isEmpty }.isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private func taskEditRow(task: Binding<EditableSuggestedTask>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("", isOn: task.isEnabled)
                    .labelsHidden()
                    .scaleEffect(0.8)

                TextField("Task name", text: task.name)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .disabled(!task.wrappedValue.isEnabled)
                    .opacity(task.wrappedValue.isEnabled ? 1 : 0.4)

                Spacer()

                Button(role: .destructive) {
                    let idToRemove = task.wrappedValue.id
                    withAnimation {
                        editableTasks.removeAll { $0.id == idToRemove }
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.6))
                }
            }

            if task.wrappedValue.isEnabled {
                HStack(spacing: 8) {
                    Picker("", selection: task.frequency) {
                        ForEach(RecurrenceType.allCases, id: \.self) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.caption)
                    .fixedSize()

                    Spacer()

                    HStack(spacing: 2) {
                        Text("x")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        TextField("", value: task.occurrences, format: .number)
                            .font(.caption)
                            .frame(width: 30)
                            .textFieldStyle(.roundedBorder)
                    }
                    .fixedSize()

                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        TextField("", value: task.reward, format: .number)
                            .font(.caption)
                            .frame(width: 30)
                            .textFieldStyle(.roundedBorder)
                    }
                    .fixedSize()

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
                    .fixedSize()
                }
                .padding(.leading, 36)
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }

    private func editableTaskBinding(_ id: UUID) -> Binding<EditableSuggestedTask> {
        Binding(
            get: { editableTasks.first { $0.id == id } ?? EditableSuggestedTask() },
            set: { newValue in
                if let idx = editableTasks.firstIndex(where: { $0.id == id }) {
                    editableTasks[idx] = newValue
                }
            }
        )
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
                        Text("Tap 'Add Goal' to pick a goal and create a plan with tasks, schedule, and rewards.")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
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
    @Environment(AuthManager.self) private var authManager
    @Environment(NotificationManager.self) private var notificationManager
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
    @State private var animatedDetailProgress: Double = 0

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
    private var isChildLocked: Bool { goal.isLocked && authManager.role != "parent" }

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
                        goalDetailMenu
                    }

                    if isEditing {
                        goalEditSection
                    }

                    // Progress
                    VStack(spacing: 8) {
                        ProgressView(value: animatedDetailProgress)
                            .tint(animatedDetailProgress >= 1.0 ? .green : category.color)
                            .scaleEffect(y: 1.5)
                        HStack {
                            Text("\(doneTasks.count)/\(goalTasks.count) tasks done")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(animatedDetailProgress * 100))%")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(animatedDetailProgress >= 1.0 ? .green : category.color)
                        }
                    }
                    .padding(.vertical, 4)
                    .onAppear {
                        animatedDetailProgress = 0
                        withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                            animatedDetailProgress = 1.0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation(.easeInOut(duration: 0.8)) {
                                animatedDetailProgress = progress
                            }
                        }
                    }
                    .onChange(of: progress) { _, newValue in
                        withAnimation(.easeOut(duration: 0.4)) {
                            animatedDetailProgress = newValue
                        }
                    }

                    // Pending Approval banner
                    if goal.isPendingApproval {
                        VStack(spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "clock.badge.checkmark.fill")
                                    .font(.title3)
                                    .foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Plan Awaiting Approval")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.orange)
                                    Text(authManager.role == "parent"
                                         ? "Review the planned tasks and approve to let the child begin."
                                         : "Waiting for parent to review and approve your plan.")
                                        .font(.caption)
                                        .foregroundStyle(theme.secondaryTextColor)
                                }
                                Spacer()
                            }

                            if authManager.role == "parent" {
                                Button {
                                    withAnimation(.snappy) {
                                        goal.status = "active"
                                    }
                                    try? modelContext.save()
                                    notificationManager.sendGoalApprovedNotification(goalName: goal.name)
                                    SoundManager.shared.playApplause()
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                } label: {
                                    Label("Approve Plan", systemImage: "checkmark.seal.fill")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(.green, in: RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                        .padding(12)
                        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }

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
                                        .background(theme.accentColor, in: Capsule())
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
                                    .foregroundStyle(isChildLocked ? .gray : category.color)
                                }
                                .disabled(isChildLocked)
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
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
                    .strikethrough()
            } else {
                Text(task.emoji)
                    .font(.system(size: 14))
                VStack(alignment: .leading, spacing: 1) {
                    Text(task.name)
                        .font(.subheadline.weight(.bold))
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
                    .font(.subheadline.weight(.bold))
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

    private var goalEditSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 6) {
                ForEach(GoalCategory.allCases) { cat in
                    Button {
                        editCategory = cat
                    } label: {
                        let isSelected = editCategory == cat
                        HStack(spacing: 3) {
                            Image(systemName: cat.icon)
                                .font(.caption2)
                            Text(cat.rawValue)
                                .font(.caption2)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                        .background(isSelected ? cat.color.opacity(0.2) : Color.primary.opacity(0.05), in: Capsule())
                        .overlay(Capsule().strokeBorder(isSelected ? cat.color : .clear, lineWidth: 1.5))
                        .foregroundStyle(isSelected ? cat.color : .primary.opacity(0.6))
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
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(theme.accentColor, in: Capsule())
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

    @ViewBuilder
    private var goalDetailMenu: some View {
        Menu {
            if !isChildLocked {
                Button {
                    editName = goal.name
                    editCategory = GoalCategory(rawValue: goal.category) ?? .lifestyle
                    editTargetDate = goal.targetDate
                    withAnimation { isEditing = true }
                } label: {
                    Label("Edit Goal", systemImage: "pencil")
                }
            }
            if goal.isActive && !isChildLocked {
                Button { goal.status = "paused"; try? modelContext.save() } label: {
                    Label("Pause", systemImage: "pause.circle")
                }
                Button { goal.status = "completed"; try? modelContext.save(); UINotificationFeedbackGenerator().notificationOccurred(.success) } label: {
                    Label("Mark Complete", systemImage: "checkmark.circle")
                }
            } else if goal.isPaused && !isChildLocked {
                Button { goal.status = "active"; try? modelContext.save() } label: {
                    Label("Resume", systemImage: "play.circle")
                }
            }
            if !isChildLocked {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete Goal", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(theme.accentColor)
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

// MARK: - Flow Layout (wrapping horizontal layout)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(in: proposal.width ?? 0, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxWidth = max(maxWidth, x - spacing)
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
