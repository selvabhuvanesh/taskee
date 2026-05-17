//
//  FamilyProjectsView.swift
//  Taskee
//

import SwiftUI
import SwiftData

// MARK: - Projects List View

struct FamilyProjectsListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Query(sort: \FamilyProject.createdAt, order: .reverse) private var projects: [FamilyProject]
    var theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default")

    @State private var showAddProject = false
    @State private var selectedFilter: String? = nil

    private var filteredProjects: [FamilyProject] {
        if let filter = selectedFilter {
            return projects.filter { $0.status == filter }
        }
        return Array(projects)
    }

    private var activeProjects: [FamilyProject] {
        filteredProjects.filter { !$0.isCompleted }
    }

    private var completedProjects: [FamilyProject] {
        filteredProjects.filter { $0.isCompleted }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: theme.gradientColors, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    filterChips

                    if filteredProjects.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                if !activeProjects.isEmpty {
                                    ForEach(activeProjects) { project in
                                        NavigationLink {
                                            ProjectDetailView(project: project, theme: theme)
                                        } label: {
                                            projectCard(project)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                if !completedProjects.isEmpty {
                                    HStack {
                                        Text("Completed")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(theme.secondaryTextColor)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.top, 8)

                                    ForEach(completedProjects) { project in
                                        NavigationLink {
                                            ProjectDetailView(project: project, theme: theme)
                                        } label: {
                                            projectCard(project)
                                                .opacity(0.6)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 100)
                        }
                    }
                }
            }
            .navigationTitle("Family Projects")
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                if authManager.role == "parent" {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { showAddProject = true } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddProject) {
                AddProjectView(theme: theme)
            }
            .environment(\.colorScheme, theme.colorScheme)
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(nil, label: "All", icon: "tray.full.fill")
                filterChip("ideating", label: "Ideating", icon: "lightbulb.fill")
                filterChip("planning", label: "Planning", icon: "list.clipboard.fill")
                filterChip("inProgress", label: "Executing", icon: "bolt.fill")
                filterChip("completed", label: "Done", icon: "checkmark.seal.fill")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func filterChip(_ status: String?, label: String, icon: String) -> some View {
        let isSelected = selectedFilter == status
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFilter = isSelected ? nil : status
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.white.opacity(0.25) : Color.white.opacity(0.1), in: Capsule())
            .foregroundStyle(isSelected ? theme.textColor : theme.secondaryTextColor)
        }
    }

    private func projectCard(_ project: FamilyProject) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: project.categoryEnum.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(project.categoryEnum.color)
                    .frame(width: 40, height: 40)
                    .background(project.categoryEnum.color.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(theme.textColor)
                        .lineLimit(1)

                    Text("by \(project.createdBy)")
                        .font(.caption)
                        .foregroundStyle(theme.tertiaryTextColor)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: project.statusIcon)
                        .font(.system(size: 10, weight: .bold))
                    Text(project.statusLabel)
                        .font(.caption2.weight(.semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(project.statusColor.opacity(0.2), in: Capsule())
                .foregroundStyle(project.statusColor)
            }

            if !project.descriptionText.isEmpty {
                Text(project.descriptionText)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryTextColor)
                    .lineLimit(2)
            }

            if let target = project.targetDate {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                    Text(target.formatted(.dateTime.month(.abbreviated).day().year()))
                        .font(.caption2)
                }
                .foregroundStyle(theme.tertiaryTextColor)
            }
        }
        .padding(14)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "paperplane.fill")
                .font(.system(size: 48))
                .foregroundStyle(theme.tertiaryTextColor)
            Text("No projects yet")
                .font(.headline)
                .foregroundStyle(theme.secondaryTextColor)
            Text("Create a family project to brainstorm, vote, and plan together")
                .font(.caption)
                .foregroundStyle(theme.tertiaryTextColor)
                .multilineTextAlignment(.center)
            if authManager.role == "parent" {
                Button {
                    showAddProject = true
                } label: {
                    Text("Create Project")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(.teal, in: Capsule())
                }
                .padding(.top, 8)
            }
            Spacer()
        }
        .padding(32)
    }
}

// MARK: - Add Project View

struct AddProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    @Environment(CloudKitManager.self) private var cloudKitManager
    var theme: ChildTheme

    @State private var name = ""
    @State private var descriptionText = ""
    @State private var selectedCategory: ProjectCategory = .home
    @State private var hasTargetDate = false
    @State private var targetDate = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: theme.gradientColors, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Project Name")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.secondaryTextColor)
                            TextField("e.g. Remodel Kitchen", text: $name)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description (optional)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.secondaryTextColor)
                            TextField("What's this project about?", text: $descriptionText, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...6)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.secondaryTextColor)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                                ForEach(ProjectCategory.allCases, id: \.self) { cat in
                                    Button {
                                        selectedCategory = cat
                                    } label: {
                                        VStack(spacing: 4) {
                                            Image(systemName: cat.icon)
                                                .font(.system(size: 18))
                                                .foregroundStyle(cat.color)
                                            Text(cat.rawValue)
                                                .font(.caption2.weight(.medium))
                                                .foregroundStyle(theme.textColor)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            selectedCategory == cat
                                                ? cat.color.opacity(0.2)
                                                : theme.cardBackgroundLight,
                                            in: RoundedRectangle(cornerRadius: 10)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(selectedCategory == cat ? cat.color : .clear, lineWidth: 1.5)
                                        )
                                    }
                                }
                            }
                        }

                        Toggle(isOn: $hasTargetDate) {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .foregroundStyle(theme.secondaryTextColor)
                                Text("Target Date")
                                    .font(.subheadline)
                                    .foregroundStyle(theme.textColor)
                            }
                        }
                        .tint(.teal)

                        if hasTargetDate {
                            DatePicker("", selection: $targetDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        saveProject()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .environment(\.colorScheme, theme.colorScheme)
        }
    }

    private func saveProject() {
        let project = FamilyProject(
            name: name.trimmingCharacters(in: .whitespaces),
            descriptionText: descriptionText.trimmingCharacters(in: .whitespaces),
            category: selectedCategory.rawValue,
            createdBy: authManager.userName,
            targetDate: hasTargetDate ? targetDate : nil
        )
        modelContext.insert(project)
        try? modelContext.save()

        let familyCode = authManager.familyCode
        Task { await cloudKitManager.pushProject(project, familyCode: familyCode) }
        dismiss()
    }
}

// MARK: - Project Detail View

struct ProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Bindable var project: FamilyProject
    var theme: ChildTheme

    @Query private var allIdeas: [ProjectIdea]
    @Query private var allVotes: [ProjectVote]
    @Query private var allTasks: [Item]
    @Query private var members: [FamilyMember]

    @State private var newIdeaText = ""
    @State private var showAddTask = false
    @State private var showDeleteConfirm = false
    @State private var editRequest: TaskEditRequest?
    @State private var taskToDelete: Item?

    private var children: [FamilyMember] {
        members.filter { $0.memberRole == "child" && $0.isAccepted }
    }

    private var otherParent: FamilyMember? {
        members.first { $0.memberRole == "parent" && $0.appleUserID != authManager.appleUserID && $0.isAccepted }
    }

    private var ideas: [ProjectIdea] {
        allIdeas.filter { $0.projectId == project.id.uuidString }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var projectTasks: [Item] {
        allTasks.filter { $0.projectId == project.id.uuidString && !$0.isArchived }
    }

    private var taskProgress: Double {
        let activeTasks = projectTasks.filter { !$0.isCancelled }
        guard !activeTasks.isEmpty else { return 0 }
        let done = activeTasks.filter { $0.isApproved }.count
        return Double(done) / Double(activeTasks.count)
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: theme.gradientColors, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    projectHeader
                    statusSection
                    ideasSection
                    tasksSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
        .toolbar {
            if authManager.role == "parent" {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(FamilyProject.statusOrder, id: \.self) { s in
                            if s != project.status {
                                Button {
                                    advanceStatus(to: s)
                                } label: {
                                    Label(statusLabelFull(s), systemImage: statusIconFor(s))
                                }
                            }
                        }
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete Project", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .alert("Delete Project?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { deleteProject() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove the project and all its ideas. Tasks already created will remain.")
        }
        .sheet(isPresented: $showAddTask) {
            AddProjectTaskView(project: project, theme: theme)
        }
        .sheet(item: $editRequest) { request in
            NavigationStack {
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
        .alert("Delete Task?", isPresented: Binding(
            get: { taskToDelete != nil },
            set: { if !$0 { taskToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let task = taskToDelete {
                    let taskId = task.id
                    modelContext.delete(task)
                    try? modelContext.save()
                    Task { await cloudKitManager.deleteRemoteTask(taskId) }
                }
                taskToDelete = nil
            }
            Button("Cancel", role: .cancel) { taskToDelete = nil }
        } message: {
            Text("This will permanently remove the task.")
        }
        .environment(\.colorScheme, theme.colorScheme)
    }

    private var projectHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: project.categoryEnum.icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(project.categoryEnum.color)
                    .frame(width: 56, height: 56)
                    .background(project.categoryEnum.color.opacity(0.2), in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text(project.categoryEnum.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(project.categoryEnum.color)

                    Text("Created by \(project.createdBy)")
                        .font(.caption)
                        .foregroundStyle(theme.tertiaryTextColor)

                    if let target = project.targetDate {
                        HStack(spacing: 3) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                            Text(target.formatted(.dateTime.month(.abbreviated).day().year()))
                                .font(.caption2)
                        }
                        .foregroundStyle(theme.secondaryTextColor)
                    }
                }
                Spacer()
            }

            if !project.descriptionText.isEmpty {
                Text(project.descriptionText)
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
    }

    private var statusSection: some View {
        VStack(spacing: 10) {
            HStack {
                ForEach(FamilyProject.statusOrder, id: \.self) { s in
                    let isCurrent = s == project.status
                    let isPast = (FamilyProject.statusOrder.firstIndex(of: s) ?? 0) < (FamilyProject.statusOrder.firstIndex(of: project.status) ?? 0)
                    VStack(spacing: 4) {
                        Circle()
                            .fill(isCurrent ? project.statusColor : (isPast ? .green.opacity(0.5) : theme.cardBackgroundLight))
                            .frame(width: 24, height: 24)
                            .overlay {
                                if isCurrent {
                                    Image(systemName: project.statusIcon)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                } else if isPast {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                        Text(statusLabelFor(s))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(isCurrent ? theme.textColor : theme.tertiaryTextColor)
                    }
                    if s != FamilyProject.statusOrder.last {
                        Rectangle()
                            .fill(isPast ? .green.opacity(0.5) : theme.cardBackgroundLight)
                            .frame(height: 2)
                    }
                }
            }

            if !projectTasks.filter({ !$0.isCancelled }).isEmpty {
                let active = projectTasks.filter { !$0.isCancelled }
                VStack(spacing: 4) {
                    ProgressView(value: taskProgress)
                        .tint(.green)
                    HStack {
                        Text("\(active.filter { $0.isApproved }.count)/\(active.count) tasks done")
                            .font(.caption2)
                            .foregroundStyle(theme.secondaryTextColor)
                        Spacer()
                        Text("\(Int(taskProgress * 100))%")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .padding(14)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Ideas Section

    private var ideasSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("Ideas")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.textColor)
                Spacer()
                Text("\(ideas.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.tertiaryTextColor)
            }

            ForEach(ideas) { idea in
                ideaRow(idea)
            }

            if project.status == "ideating" {
                HStack(spacing: 8) {
                    TextField("Add an idea...", text: $newIdeaText)
                        .textFieldStyle(.roundedBorder)
                        .font(.subheadline)

                    Button {
                        submitIdea()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.teal)
                    }
                    .disabled(newIdeaText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .padding(14)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
    }

    private func ideaRow(_ idea: ProjectIdea) -> some View {
        let votesForIdea = allVotes.filter { $0.ideaId == idea.id.uuidString }
        let upvotes = votesForIdea.filter { $0.isUpvote }.count
        let downvotes = votesForIdea.filter { !$0.isUpvote }.count
        let myVote = votesForIdea.first { $0.memberName == authManager.userName }

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(idea.text)
                    .font(.subheadline)
                    .foregroundStyle(theme.textColor)
                Text(idea.submittedBy)
                    .font(.caption2)
                    .foregroundStyle(theme.tertiaryTextColor)
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    toggleVote(idea: idea, isUpvote: true, existing: myVote)
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: myVote?.isUpvote == true ? "hand.thumbsup.fill" : "hand.thumbsup")
                            .font(.system(size: 14))
                        Text("\(upvotes)")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(myVote?.isUpvote == true ? .green : theme.secondaryTextColor)
                }

                Button {
                    toggleVote(idea: idea, isUpvote: false, existing: myVote)
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: myVote?.isUpvote == false ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                            .font(.system(size: 14))
                        Text("\(downvotes)")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(myVote?.isUpvote == false ? .red : theme.secondaryTextColor)
                }
            }
        }
        .padding(10)
        .background(theme.cardBackgroundLight, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Tasks Section

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundStyle(.teal)
                Text("Tasks")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.textColor)
                Spacer()

                if authManager.role == "parent" && !project.isCompleted {
                    Button { showAddTask = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.teal)
                    }
                }
            }

            if projectTasks.isEmpty {
                Text("No tasks created yet")
                    .font(.caption)
                    .foregroundStyle(theme.tertiaryTextColor)
                    .padding(.vertical, 8)
            } else {
                ForEach(projectTasks.sorted(by: { $0.targetDate < $1.targetDate })) { task in
                    Button {
                        editRequest = TaskEditRequest(task: task, editAll: false)
                    } label: {
                        projectTaskRow(task)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
    }

    private func projectTaskRow(_ task: Item) -> some View {
        HStack(spacing: 10) {
            Image(systemName: taskStatusIcon(task))
                .font(.system(size: 18))
                .foregroundStyle(taskStatusColor(task))

            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.subheadline)
                    .foregroundStyle(theme.textColor)
                    .strikethrough(task.isApproved || task.isCancelled)

                HStack(spacing: 6) {
                    if task.assignedTo.isEmpty {
                        Text("Unassigned")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    } else {
                        Text(task.assignedTo)
                            .font(.caption2)
                            .foregroundStyle(theme.tertiaryTextColor)
                    }
                    Text(task.targetDate.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.caption2)
                        .foregroundStyle(theme.tertiaryTextColor)
                }
            }

            Spacer()

            if task.isMissed {
                Text("Missed")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.red.opacity(0.2), in: Capsule())
            } else if task.isCancelled {
                Text("Cancelled")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.gray.opacity(0.2), in: Capsule())
            } else if task.assignedTo.isEmpty && !task.isApproved {
                Button {
                    pickUpTask(task)
                } label: {
                    Text("Pick Up")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.teal, in: Capsule())
                }
            } else if !task.assignedTo.isEmpty && !task.isApproved && !task.isInReview {
                Button {
                    unassignTask(task)
                } label: {
                    Text("Unassign")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.2), in: Capsule())
                }
            } else if task.isInReview {
                Text("Review")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.2), in: Capsule())
            }
        }
        .padding(10)
        .background(theme.cardBackgroundLight, in: RoundedRectangle(cornerRadius: 10))
        .contextMenu {
            if !task.isApproved && !task.isMissed && !task.isCancelled {
                Button {
                    updateTaskStatus(task, to: "missed")
                } label: {
                    Label("Mark as Missed", systemImage: "clock.badge.xmark")
                }
                Button(role: .destructive) {
                    updateTaskStatus(task, to: "cancelled")
                } label: {
                    Label("Cancel Task", systemImage: "xmark.circle")
                }
            }
            if task.isMissed || task.isCancelled {
                Button {
                    updateTaskStatus(task, to: "open")
                } label: {
                    Label("Reopen Task", systemImage: "arrow.uturn.backward")
                }
            }
        }
    }

    private func taskStatusIcon(_ task: Item) -> String {
        if task.isApproved { return "checkmark.circle.fill" }
        if task.isMissed { return "clock.badge.xmark.fill" }
        if task.isCancelled { return "xmark.circle.fill" }
        return "circle"
    }

    private func taskStatusColor(_ task: Item) -> Color {
        if task.isApproved { return .green }
        if task.isMissed { return .red }
        if task.isCancelled { return .gray }
        return theme.secondaryTextColor
    }

    // MARK: - Actions

    private func pickUpTask(_ task: Item) {
        task.assignedTo = authManager.userName
        try? modelContext.save()
        let familyCode = authManager.familyCode
        Task { await cloudKitManager.pushTask(task, familyCode: familyCode) }
    }

    private func unassignTask(_ task: Item) {
        task.assignedTo = ""
        try? modelContext.save()
        let familyCode = authManager.familyCode
        Task { await cloudKitManager.pushTask(task, familyCode: familyCode) }
    }

    private func updateTaskStatus(_ task: Item, to status: String) {
        task.status = status
        try? modelContext.save()
        let familyCode = authManager.familyCode
        Task { await cloudKitManager.pushTask(task, familyCode: familyCode) }
    }

    private func submitIdea() {
        let text = newIdeaText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        let idea = ProjectIdea(
            projectId: project.id.uuidString,
            text: text,
            submittedBy: authManager.userName
        )
        modelContext.insert(idea)
        try? modelContext.save()
        newIdeaText = ""

        let familyCode = authManager.familyCode
        Task { await cloudKitManager.pushIdea(idea, familyCode: familyCode) }
    }

    private func toggleVote(idea: ProjectIdea, isUpvote: Bool, existing: ProjectVote?) {
        let familyCode = authManager.familyCode

        if let existing = existing {
            if existing.isUpvote == isUpvote {
                modelContext.delete(existing)
                try? modelContext.save()
                Task { await cloudKitManager.deleteRemoteVote(existing.id) }
            } else {
                existing.isUpvote = isUpvote
                try? modelContext.save()
                Task { await cloudKitManager.pushVote(existing, familyCode: familyCode) }
            }
        } else {
            let vote = ProjectVote(
                ideaId: idea.id.uuidString,
                memberName: authManager.userName,
                isUpvote: isUpvote
            )
            modelContext.insert(vote)
            try? modelContext.save()
            Task { await cloudKitManager.pushVote(vote, familyCode: familyCode) }
        }
    }

    private func advanceStatus(to newStatus: String) {
        project.status = newStatus
        try? modelContext.save()
        let familyCode = authManager.familyCode
        Task { await cloudKitManager.pushProject(project, familyCode: familyCode) }
    }

    private func deleteProject() {
        let familyCode = authManager.familyCode
        let projectUUID = project.id

        let ideasToDelete = ideas
        for idea in ideasToDelete {
            let votes = allVotes.filter { $0.ideaId == idea.id.uuidString }
            for vote in votes {
                let voteId = vote.id
                modelContext.delete(vote)
                Task { await cloudKitManager.deleteRemoteVote(voteId) }
            }
            let ideaId = idea.id
            modelContext.delete(idea)
            Task { await cloudKitManager.deleteRemoteIdea(ideaId) }
        }

        for task in projectTasks {
            task.projectId = ""
            Task { await cloudKitManager.pushTask(task, familyCode: familyCode) }
        }

        modelContext.delete(project)
        try? modelContext.save()
        Task { await cloudKitManager.deleteRemoteProject(projectUUID) }
    }

    private func statusLabelFor(_ s: String) -> String {
        switch s {
        case "ideating": return "Ideate"
        case "planning": return "Plan"
        case "inProgress": return "Execute"
        case "completed": return "Done"
        default: return s
        }
    }

    private func statusLabelFull(_ s: String) -> String {
        switch s {
        case "ideating": return "Move to Ideating"
        case "planning": return "Move to Planning"
        case "inProgress": return "Move to Executing"
        case "completed": return "Mark Completed"
        default: return s
        }
    }

    private func statusIconFor(_ s: String) -> String {
        switch s {
        case "ideating": return "lightbulb.fill"
        case "planning": return "list.clipboard.fill"
        case "inProgress": return "bolt.fill"
        case "completed": return "checkmark.seal.fill"
        default: return "folder.fill"
        }
    }
}

// MARK: - Add Project Task View

struct AddProjectTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Environment(NotificationManager.self) private var notificationManager
    let project: FamilyProject
    var theme: ChildTheme

    @Query private var members: [FamilyMember]

    @State private var taskName = ""
    @State private var targetDate = Date()
    @State private var selectedMember = ""
    @State private var reward: Double = 0

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: theme.gradientColors, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: project.categoryEnum.icon)
                                .foregroundStyle(project.categoryEnum.color)
                            Text(project.name)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.secondaryTextColor)
                        }
                        .padding(8)
                        .background(theme.cardBackgroundLight, in: Capsule())

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Task Name")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.secondaryTextColor)
                            TextField("What needs to be done?", text: $taskName)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Assign To (optional)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.secondaryTextColor)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    Button {
                                        selectedMember = ""
                                    } label: {
                                        Text("Unassigned")
                                            .font(.caption.weight(.medium))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                selectedMember.isEmpty ? Color.orange.opacity(0.3) : theme.cardBackgroundLight,
                                                in: Capsule()
                                            )
                                            .foregroundStyle(selectedMember.isEmpty ? .orange : theme.textColor)
                                    }

                                    ForEach(members.filter { $0.isAccepted }, id: \.id) { member in
                                        Button {
                                            selectedMember = member.name
                                        } label: {
                                            Text(member.name)
                                                .font(.caption.weight(.medium))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(
                                                    selectedMember == member.name ? Color.teal.opacity(0.3) : theme.cardBackgroundLight,
                                                    in: Capsule()
                                                )
                                                .foregroundStyle(selectedMember == member.name ? .teal : theme.textColor)
                                        }
                                    }
                                }
                            }
                        }

                        DatePicker("Due Date", selection: $targetDate, displayedComponents: [.date, .hourAndMinute])
                            .font(.subheadline)
                            .foregroundStyle(theme.textColor)

                        HStack {
                            Text("Reward")
                                .font(.subheadline)
                                .foregroundStyle(theme.textColor)
                            Spacer()
                            TextField("0", value: $reward, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .keyboardType(.decimalPad)
                            Text("coins")
                                .font(.caption)
                                .foregroundStyle(theme.secondaryTextColor)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Project Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { saveTask() }
                        .disabled(taskName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .environment(\.colorScheme, theme.colorScheme)
        }
    }

    private func saveTask() {
        let task = Item(
            name: taskName.trimmingCharacters(in: .whitespaces),
            targetDate: targetDate,
            assignedTo: selectedMember,
            reward: reward,
            createdBy: authManager.userName,
            createdByID: authManager.appleUserID,
            projectId: project.id.uuidString
        )
        modelContext.insert(task)
        try? modelContext.save()

        if !selectedMember.isEmpty {
            notificationManager.scheduleTaskReminder(
                taskId: task.id,
                taskName: task.name,
                assignedTo: task.assignedTo,
                dueDate: task.targetDate
            )

            if selectedMember != authManager.userName {
                notificationManager.sendTaskAssignedNotification(
                    taskName: task.name,
                    assignerName: authManager.userName
                )
            }
        }

        let familyCode = authManager.familyCode
        Task {
            await cloudKitManager.pushTask(task, familyCode: familyCode)
        }

        dismiss()
    }
}
