//
//  WatchContentView.swift
//  TaskeeWatch Watch App
//
//  Created by Selva Bhuvanesh on 4/25/26.
//

import SwiftUI
import SwiftData

// MARK: - Watch Task List View
// Displays all tasks on the Apple Watch sorted by target date.

struct WatchContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.targetDate) private var tasks: [Item]

    var body: some View {
        NavigationStack {
            // MARK: Task List
            // Shows each task; tapping toggles completion.
            List {
                ForEach(tasks) { task in
                    WatchTaskRow(task: task)
                }
                .onDelete(perform: deleteTasks)
            }
            .navigationTitle("Taskee")
            // MARK: Empty State
            // Shown when no tasks exist.
            .overlay {
                if tasks.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checklist")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No Tasks")
                            .font(.headline)
                        Text("Add tasks on your iPhone.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: Delete Tasks
    // Removes selected tasks from the SwiftData store.
    private func deleteTasks(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(tasks[index])
            }
        }
    }
}

// MARK: - Watch Task Row
// Compact row showing completion status, task name, and due date for the Watch.

struct WatchTaskRow: View {
    @Bindable var task: Item

    var body: some View {
        // MARK: Completion Toggle & Details
        // Tapping the row toggles the task's completion state.
        Button {
            withAnimation {
                task.isCompleted.toggle()
            }
        } label: {
            HStack {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? .green : .gray)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.name)
                        .font(.body)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)

                    Text(task.targetDate, format: .dateTime.month().day())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WatchContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
