//
//  AIAssistantView.swift
//  Taskee
//

import SwiftUI
import SwiftData
import Speech
import AVFoundation

// MARK: - Claude API Service (via proxy)

final class ClaudeAPIService: Sendable {
    static let shared = ClaudeAPIService()
    static let sonnetModel = "claude-sonnet-4-6"
    static let haikuModel = "claude-haiku-4-5-20251001"
    private let proxyURL = URL(string: "https://taskoot-ai-proxy.selvabhuvanesh.workers.dev")!
    private let appToken = "taskoot-app-2026"

    var hasAPIKey: Bool { true }

    struct ClaudeResponse {
        let message: String
        let action: ParsedAction?
    }

    struct ParsedAction {
        let intent: String
        let taskName: String?
        let assignee: String?
        let date: String?
        let reward: Int?
        let matchingTaskNames: [String]?
        let newDate: String?
        let preserveTime: Bool
        let rescheduleScope: String?
        let recurrence: String?
        let occurrences: Int?
    }

    func chat(
        userMessage: String,
        conversationHistory: [(role: String, text: String)],
        familyMembers: [String],
        currentUser: String,
        isIndividual: Bool,
        tasksSummary: String,
        model: String = ClaudeAPIService.sonnetModel
    ) async throws -> ClaudeResponse {
        let systemPrompt = buildSystemPrompt(
            familyMembers: familyMembers,
            currentUser: currentUser,
            isIndividual: isIndividual,
            tasksSummary: tasksSummary
        )

        var apiMessages: [[String: String]] = []
        for entry in conversationHistory.suffix(10) {
            apiMessages.append(["role": entry.role, "content": entry.text])
        }
        apiMessages.append(["role": "user", "content": userMessage])

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": apiMessages
        ]

        var request = URLRequest(url: proxyURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(appToken, forHTTPHeaderField: "X-App-Token")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw APIError.httpError(statusCode, errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw APIError.parseError
        }

        return parseResponse(text)
    }

    private func buildSystemPrompt(familyMembers: [String], currentUser: String, isIndividual: Bool, tasksSummary: String) -> String {
        let memberList = familyMembers.joined(separator: ", ")
        let now = Date()
        let today = now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year())
        let currentTime = now.formatted(.dateTime.hour().minute())
        let timezone = TimeZone.current.identifier

        return """
        You are a helpful family task management assistant in the Taskoot app. Today is \(today), current time is \(currentTime) (\(timezone)).
        Current user: \(currentUser). \(isIndividual ? "This user manages tasks individually (no family)." : "Family members: \(memberList).")

        CURRENT TASKS:
        \(tasksSummary)

        You help users create, reschedule, cancel, and complete tasks. You also answer questions about task status, coins earned, and weekly summaries.

        RESPONSE FORMAT — you MUST respond with valid JSON only, no extra text:
        {
            "message": "Your conversational response to the user",
            "action": null or {
                "intent": "create|reschedule|cancel|markDone",
                "taskName": "the task name",
                "assignee": "person name or null",
                "date": "ISO 8601 datetime or null",
                "reward": number or null,
                "matchingTaskNames": ["task names to match"] or null,
                "newDate": "ISO 8601 datetime for reschedule target",
                "preserveTime": true or false,
                "rescheduleScope": "instance" or "series",
                "recurrence": "none|daily|weekly|monthly",
                "occurrences": number or null
            }
        }

        RULES:
        - Set "action" to null for questions, status checks, summaries, clarifications, or when information is missing.
        - IMPORTANT: For ANY task creation, reschedule, cancel, or markDone — you MUST ALWAYS include the "action" object so the user sees a preview and can confirm before it executes. Never just describe what you would do in text — always provide the action for user confirmation.
        - For "create": require at minimum a task name. If assignee is missing\(isIndividual ? ", default to \(currentUser)" : " and there are multiple family members, ask who to assign to"). If date is missing, mention you'll default to today. Always include the action so the user can review and confirm the task details before creation.
          - To create a recurring task, set "recurrence" to "daily", "weekly", or "monthly" and "occurrences" to the number of instances to create. Defaults: daily=7, weekly=4, monthly=3 if not specified. The "date" is the start date/time; instances are generated from there.
          - Examples: "Add homework daily for 2 weeks" → recurrence: "daily", occurrences: 14. "Create swimming weekly for a month" → recurrence: "weekly", occurrences: 4.
        - For "reschedule": use "matchingTaskNames" with task names to match, and "newDate" for the target date and time.
          - If the user specifies a new TIME (e.g. "move to 3pm", "change to 10am"), include that time in "newDate" and set "preserveTime" to false.
          - If the user only specifies a new DATE without a time (e.g. "move to tomorrow", "push to Saturday"), set "preserveTime" to true so the original time is kept.
          - If the matched task is marked [recurring], you MUST ask the user whether to change just this instance or the entire series BEFORE setting the action. Set "action" to null and ask. Once the user answers, set "rescheduleScope" to "instance" or "series".
        - For "cancel" and "markDone": use "matchingTaskNames" with the task names to match. Always include the action for user confirmation. Include "rescheduleScope" field for cancel too — if the task is [recurring], ask the user whether to cancel/delete just this instance or all recurring instances before setting the action.
        - After any action is confirmed, provide a clear confirmation summary of exactly what was done (task name, new date/time, who it's assigned to, etc.).
        - Be conversational, friendly, and concise. Ask clarifying questions when the request is ambiguous.
        - When listing tasks or summarizing, use the task data provided above.
        - ALL dates in the action MUST be ISO 8601 format in the user's LOCAL time WITHOUT timezone suffix. Example: "2026-05-28T19:00:00" (NOT "2026-05-28T19:00:00Z"). Never append "Z" or any timezone offset.
        - ALWAYS respond with valid JSON. Never include markdown, backticks, or text outside the JSON object.
        """
    }

    private func parseResponse(_ text: String) -> ClaudeResponse {
        var jsonText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip markdown code blocks anywhere in the response
        if let codeStart = jsonText.range(of: "```(?:json)?\\s*", options: .regularExpression),
           let codeEnd = jsonText.range(of: "```", options: .backwards, range: codeStart.upperBound..<jsonText.endIndex) {
            jsonText = String(jsonText[codeStart.upperBound..<codeEnd.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Find JSON object boundaries if text doesn't start with {
        if !jsonText.hasPrefix("{"),
           let start = jsonText.firstIndex(of: "{"),
           let end = jsonText.lastIndex(of: "}") {
            jsonText = String(jsonText[start...end])
        }

        guard let data = jsonText.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? String else {
            return ClaudeResponse(message: text, action: nil)
        }

        var parsedAction: ParsedAction?
        if let actionJson = json["action"] as? [String: Any],
           let intent = actionJson["intent"] as? String {
            parsedAction = ParsedAction(
                intent: intent,
                taskName: actionJson["taskName"] as? String,
                assignee: actionJson["assignee"] as? String,
                date: actionJson["date"] as? String,
                reward: actionJson["reward"] as? Int,
                matchingTaskNames: actionJson["matchingTaskNames"] as? [String],
                newDate: actionJson["newDate"] as? String,
                preserveTime: actionJson["preserveTime"] as? Bool ?? true,
                rescheduleScope: actionJson["rescheduleScope"] as? String,
                recurrence: actionJson["recurrence"] as? String,
                occurrences: actionJson["occurrences"] as? Int
            )
        }

        return ClaudeResponse(message: message, action: parsedAction)
    }

    enum APIError: Error {
        case httpError(Int, String), parseError
    }
}

// MARK: - Chat Memory (persisted for 24 hours)

struct SavedChatMessage: Codable {
    let id: String
    let role: String
    let text: String
    let timestamp: Date
    var actionExecuted: Bool
    var actionCancelled: Bool

    init(from message: AIChatMessage) {
        self.id = message.id.uuidString
        self.role = message.role == .user ? "user" : "assistant"
        self.text = message.text
        self.timestamp = message.timestamp
        self.actionExecuted = message.action?.isExecuted ?? false
        self.actionCancelled = message.action?.isCancelled ?? false
    }

    func toMessage() -> AIChatMessage {
        var action: TaskAction?
        if actionExecuted {
            action = TaskAction(intent: .unknown, summary: "", details: [], isExecuted: true)
        } else if actionCancelled {
            action = TaskAction(intent: .unknown, summary: "", details: [], isCancelled: true)
        }
        return AIChatMessage(
            id: UUID(uuidString: id) ?? UUID(),
            role: role == "user" ? .user : .assistant,
            text: text,
            action: action,
            timestamp: timestamp
        )
    }
}

enum ChatMemory {
    private static let key = "aiAssistantChatHistory"
    private static let retention: TimeInterval = 24 * 60 * 60

    static func save(_ messages: [AIChatMessage]) {
        let saved = messages.map { SavedChatMessage(from: $0) }
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func load() -> [AIChatMessage] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode([SavedChatMessage].self, from: data) else {
            return []
        }
        let cutoff = Date().addingTimeInterval(-retention)
        return saved
            .filter { $0.timestamp > cutoff }
            .map { $0.toMessage() }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - Chat Message

struct AIChatMessage: Identifiable {
    let id: UUID
    let role: Role
    let text: String
    var action: TaskAction?
    let timestamp: Date

    enum Role { case user, assistant }

    init(id: UUID = UUID(), role: Role, text: String, action: TaskAction? = nil, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.action = action
        self.timestamp = timestamp
    }
}

// MARK: - Task Action (preview card)

struct TaskAction: Identifiable {
    let id = UUID()
    let intent: TaskIntent
    let summary: String
    let details: [String]
    var isExecuted = false
    var isCancelled = false

    var tasks: [Item] = []
    var newDate: Date?
    var newAssignee: String?
    var parsedTask: ParsedTask?
    var preserveTime: Bool = true
    var rescheduleScope: String = "instance"
}

// MARK: - Task Intent

enum TaskIntent {
    case create
    case reschedule
    case cancel
    case markDone
    case listTasks
    case checkCoins
    case weekSummary
    case status
    case unknown
}

// MARK: - Pending Conversation Context

enum PendingContext {
    case none
    case awaitingTaskName(intent: TaskIntent)
    case awaitingDate(intent: TaskIntent, tasks: [Item], person: String?)
    case awaitingAssignee(name: String, date: Date, reward: Int, recurrence: RecurrenceType)
    case awaitingCreateConfirmation(name: String, assignee: String, date: Date, reward: Int, recurrence: RecurrenceType)
    case awaitingPerson(intent: TaskIntent)
}

// MARK: - Command Parser

struct TaskCommandParser {
    let familyMembers: [String]
    let currentUser: String
    let allTasks: [Item]
    let isIndividual: Bool

    func parse(_ input: String, context: PendingContext) -> (intent: TaskIntent, response: String, action: TaskAction?, newContext: PendingContext) {
        let lower = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if let result = handlePendingContext(lower, input, context: context) { return result }
        if let result = tryReschedule(lower, input) { return result }
        if let result = tryCancel(lower, input) { return result }
        if let result = tryMarkDone(lower, input) { return result }
        if let result = tryCreate(lower, input) { return result }
        if let result = tryListTasks(lower) { return result }
        if let result = tryCheckCoins(lower) { return result }
        if let result = tryWeekSummary(lower) { return result }
        if let result = tryStatus(lower, input) { return result }

        return (.unknown, "I didn't quite catch that. Here's what I can help with:\n\n• Create tasks — \"Add homework for Arya tomorrow 5pm\"\n• Reschedule — \"Move today's tasks to Saturday\"\n• Cancel or complete — \"Cancel swimming\" / \"Mark reading as done\"\n• Check status — \"What's Arya doing today?\"\n• Summaries — \"How did we do last week?\"", nil, .none)
    }

    // MARK: - Handle Pending Context

    private func handlePendingContext(_ lower: String, _ original: String, context: PendingContext) -> (TaskIntent, String, TaskAction?, PendingContext)? {
        switch context {
        case .none:
            return nil

        case .awaitingTaskName(let intent):
            let trimmed = original.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            if intent == .create {
                let parser = SmartTaskParser(familyMembers: familyMembers)
                let parsed = parser.parse(trimmed)
                if parsed.name.isEmpty {
                    return (.create, "I didn't catch the task name. Could you tell me what task you'd like to create?", nil, .awaitingTaskName(intent: .create))
                }
                return buildCreatePreview(parsed)
            }
            return nil

        case .awaitingDate(let intent, let tasks, _):
            let date = extractDate(from: lower)
            guard let date else {
                return (intent, "I couldn't understand that date. Try something like \"tomorrow\", \"Saturday\", or \"next week\".", nil, context)
            }
            if intent == .reschedule && !tasks.isEmpty {
                return buildRescheduleAction(tasks: tasks, targetDate: date)
            }
            return nil

        case .awaitingAssignee(let name, let date, let reward, let recurrence):
            let person = extractPerson(from: original) ?? original.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchedMember = familyMembers.first { $0.localizedCaseInsensitiveCompare(person) == .orderedSame }
            guard let assignee = matchedMember else {
                let memberList = familyMembers.joined(separator: ", ")
                return (.create, "I don't recognize \"\(person)\". Your family members are: \(memberList). Who should I assign this to?", nil, context)
            }
            return (.create, "Got it! Here's what I'll create:", buildCreateAction(name: name, assignee: assignee, date: date, reward: reward, recurrence: recurrence), .none)

        case .awaitingPerson(let intent):
            let person = extractPerson(from: original) ?? original.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchedMember = familyMembers.first { $0.localizedCaseInsensitiveCompare(person) == .orderedSame }
            guard let member = matchedMember else {
                let memberList = familyMembers.joined(separator: ", ")
                return (intent, "I don't recognize \"\(person)\". Your family members are: \(memberList).", nil, context)
            }
            if intent == .listTasks {
                let tasks = todayTasks.filter { $0.assignedTo == member }
                return formatTaskList(tasks: tasks, person: member, dateLabel: "today")
            }
            return nil

        case .awaitingCreateConfirmation:
            return nil
        }
    }

    // MARK: - Reschedule

    private func tryReschedule(_ lower: String, _ original: String) -> (TaskIntent, String, TaskAction?, PendingContext)? {
        let reschedulePatterns = ["move", "reschedule", "push", "shift", "postpone", "delay"]
        guard reschedulePatterns.contains(where: { lower.contains($0) }) else { return nil }

        let targetDate = extractDate(from: lower)
        let person = extractPerson(from: original)
        let taskName = extractTaskName(from: lower, excluding: reschedulePatterns + dateWords)

        var matchingTasks: [Item]

        if !taskName.isEmpty {
            matchingTasks = todayAndFutureTasks.filter {
                $0.isOpen && $0.name.localizedCaseInsensitiveContains(taskName)
            }
            if let person {
                matchingTasks = matchingTasks.filter { $0.assignedTo == person }
            }
        } else if let person {
            matchingTasks = todayTasks.filter { $0.isOpen && $0.assignedTo == person }
        } else if lower.contains("today") || lower.contains("all") {
            matchingTasks = todayTasks.filter { $0.isOpen }
        } else {
            return (.reschedule, "Sure, I can help reschedule tasks. Which tasks would you like to move? For example:\n• \"Move Arya's homework to tomorrow\"\n• \"Push all tasks to Saturday\"", nil, .none)
        }

        guard !matchingTasks.isEmpty else {
            return (.reschedule, "I looked but couldn't find any matching open tasks. Could you double-check the name or person?", nil, .none)
        }

        guard let targetDate else {
            let taskLabel = matchingTasks.count == 1 ? "\"\(matchingTasks[0].name)\"" : "these \(matchingTasks.count) tasks"
            return (.reschedule, "I found \(taskLabel). When should I reschedule to? Try \"tomorrow\", \"Saturday\", or a specific date.", nil, .awaitingDate(intent: .reschedule, tasks: matchingTasks, person: person))
        }

        return buildRescheduleAction(tasks: matchingTasks, targetDate: targetDate)
    }

    private func buildRescheduleAction(tasks: [Item], targetDate: Date) -> (TaskIntent, String, TaskAction?, PendingContext) {
        let details = tasks.map { task in
            "\(task.emoji) \(task.name) — \(task.targetDate.formatted(.dateTime.weekday(.abbreviated).hour().minute())) → \(targetDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))"
        }

        let action = TaskAction(
            intent: .reschedule,
            summary: "Reschedule \(tasks.count) task\(tasks.count == 1 ? "" : "s")",
            details: details,
            tasks: tasks,
            newDate: targetDate
        )

        let taskWord = tasks.count == 1 ? "task" : "\(tasks.count) tasks"
        return (.reschedule, "I'll reschedule \(taskWord) to \(targetDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())). Please confirm:", action, .none)
    }

    // MARK: - Cancel

    private func tryCancel(_ lower: String, _ original: String) -> (TaskIntent, String, TaskAction?, PendingContext)? {
        let cancelPatterns = ["cancel", "remove", "delete"]
        guard cancelPatterns.contains(where: { lower.contains($0) }) else { return nil }

        let person = extractPerson(from: original)
        let taskName = extractTaskName(from: lower, excluding: cancelPatterns)

        var matchingTasks: [Item]

        if !taskName.isEmpty {
            matchingTasks = todayAndFutureTasks.filter {
                $0.isOpen && $0.name.localizedCaseInsensitiveContains(taskName)
            }
            if let person {
                matchingTasks = matchingTasks.filter { $0.assignedTo == person }
            }
        } else if let person {
            matchingTasks = todayTasks.filter { $0.isOpen && $0.assignedTo == person }
        } else {
            return (.cancel, "Which task would you like to cancel? Tell me the task name or person, like \"Cancel Arya's swimming\".", nil, .none)
        }

        guard !matchingTasks.isEmpty else {
            return (.cancel, "I couldn't find any matching open tasks to cancel. Make sure the task is still open and the name is correct.", nil, .none)
        }

        if matchingTasks.count > 5 {
            return (.cancel, "That matches \(matchingTasks.count) tasks. Could you be more specific? Try including the task name, like \"Cancel homework\".", nil, .none)
        }

        let details = matchingTasks.map { "\($0.emoji) \($0.name) — \($0.assignedTo.isEmpty ? "" : "\($0.assignedTo), ")\($0.targetDate.formatted(.dateTime.weekday(.abbreviated).hour().minute()))" }

        let action = TaskAction(
            intent: .cancel,
            summary: "Cancel \(matchingTasks.count) task\(matchingTasks.count == 1 ? "" : "s")",
            details: details,
            tasks: matchingTasks
        )

        let warning = matchingTasks.count > 1 ? " This will cancel all \(matchingTasks.count) tasks." : ""
        return (.cancel, "I'll cancel the following task\(matchingTasks.count == 1 ? "" : "s").\(warning) Please confirm:", action, .none)
    }

    // MARK: - Mark Done

    private func tryMarkDone(_ lower: String, _ original: String) -> (TaskIntent, String, TaskAction?, PendingContext)? {
        let donePatterns = ["mark", "complete", "done", "finish", "approve"]
        guard donePatterns.contains(where: { lower.contains($0) }) else { return nil }
        guard lower.contains("done") || lower.contains("complete") || lower.contains("finish") || lower.contains("approve") else { return nil }

        let person = extractPerson(from: original)
        let taskName = extractTaskName(from: lower, excluding: donePatterns + ["as", "it"])

        var matchingTasks: [Item]

        if !taskName.isEmpty {
            matchingTasks = allTasks.filter {
                ($0.isOpen || $0.isInReview) && $0.name.localizedCaseInsensitiveContains(taskName)
            }
            if let person {
                matchingTasks = matchingTasks.filter { $0.assignedTo == person }
            }
        } else if let person {
            matchingTasks = todayTasks.filter { ($0.isOpen || $0.isInReview) && $0.assignedTo == person }
        } else {
            return (.markDone, "Which task should I mark as done? Try something like \"Mark Arya's reading as done\".", nil, .none)
        }

        guard !matchingTasks.isEmpty else {
            return (.markDone, "I couldn't find any open tasks matching that. The task might already be completed or the name might be different.", nil, .none)
        }

        let details = matchingTasks.map { "\($0.emoji) \($0.name)\($0.assignedTo.isEmpty ? "" : " (\($0.assignedTo))")" }
        let coinsPreview = matchingTasks.filter { $0.reward > 0 }.reduce(0) { $0 + Int($1.reward) }
        var coinNote = ""
        if coinsPreview > 0 { coinNote = "\n\n\(coinsPreview) coins will be earned!" }

        let action = TaskAction(
            intent: .markDone,
            summary: "Mark \(matchingTasks.count) task\(matchingTasks.count == 1 ? "" : "s") as done",
            details: details,
            tasks: matchingTasks
        )

        return (.markDone, "I'll mark the following as done.\(coinNote) Please confirm:", action, .none)
    }

    // MARK: - Create

    private func tryCreate(_ lower: String, _ original: String) -> (TaskIntent, String, TaskAction?, PendingContext)? {
        let createPatterns = ["add", "create", "new task", "schedule", "assign", "set up", "give"]
        guard createPatterns.contains(where: { lower.contains($0) }) else { return nil }

        let parser = SmartTaskParser(familyMembers: familyMembers)
        let parsed = parser.parse(original)

        if parsed.name.isEmpty {
            return (.create, "Sure, I can create a task! What's the task name? For example: \"homework tomorrow 5pm\" or \"grocery shopping Saturday 10am 3 coins\".", nil, .awaitingTaskName(intent: .create))
        }

        return buildCreatePreview(parsed)
    }

    private func buildCreatePreview(_ parsed: ParsedTask) -> (TaskIntent, String, TaskAction?, PendingContext) {
        if !isIndividual && parsed.assignedTo.isEmpty && familyMembers.count > 1 {
            let memberList = familyMembers.joined(separator: ", ")
            return (.create, "Got it — \"\(parsed.name)\" on \(parsed.targetDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().hour().minute())). Who should I assign this to? (\(memberList))", nil, .awaitingAssignee(name: parsed.name, date: parsed.targetDate, reward: parsed.reward, recurrence: parsed.recurrence))
        }

        let assignee = parsed.assignedTo.isEmpty ? currentUser : parsed.assignedTo
        let action = buildCreateAction(name: parsed.name, assignee: assignee, date: parsed.targetDate, reward: parsed.reward, recurrence: parsed.recurrence)

        var summary = "Here's what I'll create for \(assignee):"
        if !parsed.hasDate {
            summary = "I'll set this for today since no date was specified. Here's the preview:"
        }

        return (.create, summary, action, .none)
    }

    private func buildCreateAction(name: String, assignee: String, date: Date, reward: Int, recurrence: RecurrenceType) -> TaskAction {
        var details = [name]
        details.append("📅 \(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().hour().minute()))")
        details.append("👤 \(assignee)")
        if reward > 0 { details.append("⭐ \(reward) coins") }
        if recurrence != .none { details.append("🔄 \(recurrence.rawValue)") }

        var parsed = ParsedTask()
        parsed.name = name
        parsed.targetDate = date
        parsed.assignedTo = assignee
        parsed.reward = reward
        parsed.recurrence = recurrence

        var action = TaskAction(
            intent: .create,
            summary: "Create new task",
            details: details,
            tasks: []
        )
        action.parsedTask = parsed
        action.newAssignee = assignee
        return action
    }

    // MARK: - List Tasks

    private func tryListTasks(_ lower: String) -> (TaskIntent, String, TaskAction?, PendingContext)? {
        let queryPatterns = ["what", "show", "list", "tell me", "what's", "whats"]
        let taskKeywords = ["task", "doing", "have", "due", "scheduled", "todo", "to do", "to-do"]
        guard queryPatterns.contains(where: { lower.contains($0) }) &&
              taskKeywords.contains(where: { lower.contains($0) }) else { return nil }

        let person = extractPersonFromQuery(from: lower)
        let isTomorrow = lower.contains("tomorrow")
        let isWeek = lower.contains("week") || lower.contains("this week")

        var tasks: [Item]
        var dateLabel: String

        if isWeek {
            let endOfWeek = Calendar.current.date(byAdding: .day, value: 7, to: Calendar.current.startOfDay(for: Date()))!
            tasks = allTasks.filter {
                let d = Calendar.current.startOfDay(for: $0.targetDate)
                return d >= Calendar.current.startOfDay(for: Date()) && d < endOfWeek && !$0.isArchived
            }
            dateLabel = "this week"
        } else if isTomorrow {
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
            tasks = allTasks.filter { Calendar.current.isDate($0.targetDate, inSameDayAs: tomorrow) && !$0.isArchived }
            dateLabel = "tomorrow"
        } else {
            tasks = todayTasks
            dateLabel = "today"
        }

        if let person {
            tasks = tasks.filter { $0.assignedTo == person }
        }

        return formatTaskList(tasks: tasks, person: person, dateLabel: dateLabel)
    }

    private func formatTaskList(tasks: [Item], person: String?, dateLabel: String) -> (TaskIntent, String, TaskAction?, PendingContext) {
        let sorted = tasks.sorted { $0.targetDate < $1.targetDate }

        if sorted.isEmpty {
            let who = person ?? (isIndividual ? "you" : "anyone")
            return (.listTasks, "No tasks scheduled for \(who) \(dateLabel). Looks like a free day! 🎉", nil, .none)
        }

        var lines: [String] = []
        for task in sorted.prefix(15) {
            let status = task.isApproved ? "✅" : task.isInReview ? "🟡" : task.isMissed ? "❌" : "⬜"
            let time = task.targetDate.formatted(.dateTime.hour().minute())
            let who = (!isIndividual && person == nil && !task.assignedTo.isEmpty) ? " (\(task.assignedTo))" : ""
            lines.append("\(status) \(task.emoji) \(task.name) — \(time)\(who)")
        }

        let header = person != nil ? "\(person!)'s tasks \(dateLabel)" : "Tasks \(dateLabel)"
        let countNote = sorted.count > 15 ? "\n...and \(sorted.count - 15) more" : ""
        let open = sorted.filter { $0.isOpen }.count
        let done = sorted.filter { $0.isApproved }.count
        let summary = "\n\n📊 \(done) done, \(open) remaining out of \(sorted.count)"

        return (.listTasks, "📋 **\(header)** (\(sorted.count)):\n\n\(lines.joined(separator: "\n"))\(countNote)\(summary)", nil, .none)
    }

    // MARK: - Check Coins

    private func tryCheckCoins(_ lower: String) -> (TaskIntent, String, TaskAction?, PendingContext)? {
        guard lower.contains("coin") || lower.contains("reward") || lower.contains("earned") || lower.contains("points") else { return nil }
        guard lower.contains("how") || lower.contains("many") || lower.contains("check") || lower.contains("show") || lower.contains("what") else { return nil }

        let person = extractPersonFromQuery(from: lower)
        let targetName = person ?? currentUser

        let earned = allTasks
            .filter { $0.assignedTo == targetName && $0.isApproved && $0.reward > 0 }
            .reduce(0) { $0 + Int($1.reward) }

        let inReview = allTasks
            .filter { $0.assignedTo == targetName && $0.isInReview && $0.reward > 0 }
            .reduce(0) { $0 + Int($1.reward) }

        var response = "⭐ **\(targetName)'s Coins**\n\n"
        response += "Earned: \(earned) coins\n"
        if inReview > 0 {
            response += "Pending review: \(inReview) coins\n"
        }

        return (.checkCoins, response, nil, .none)
    }

    // MARK: - Week Summary

    private func tryWeekSummary(_ lower: String) -> (TaskIntent, String, TaskAction?, PendingContext)? {
        let weekPatterns = ["last week", "past week", "week summary", "weekly", "how did", "how was"]
        guard weekPatterns.contains(where: { lower.contains($0) }) else { return nil }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!

        let pastTasks = allTasks.filter {
            let d = calendar.startOfDay(for: $0.targetDate)
            return d >= weekAgo && d < today
        }

        let total = pastTasks.count
        let done = pastTasks.filter { $0.isApproved }.count
        let missed = pastTasks.filter { $0.isMissed }.count
        let cancelled = pastTasks.filter { $0.isCancelled }.count
        let rate = total > 0 ? Int(Double(done) / Double(total) * 100) : 0
        let coins = pastTasks.filter { $0.isApproved && $0.reward > 0 }.reduce(0) { $0 + Int($1.reward) }

        var response = "📊 **Past Week Summary**\n\n"
        response += "Completion: \(rate)% (\(done)/\(total))\n"
        if missed > 0 { response += "Missed: \(missed)\n" }
        if cancelled > 0 { response += "Cancelled: \(cancelled)\n" }
        if coins > 0 { response += "Coins earned: \(coins) ⭐\n" }

        if !isIndividual {
            let members = Set(pastTasks.compactMap { $0.assignedTo.isEmpty ? nil : $0.assignedTo })
            if members.count >= 2 {
                response += "\n**By member:**\n"
                for name in members.sorted() {
                    let memberDone = pastTasks.filter { $0.assignedTo == name && $0.isApproved }.count
                    let memberTotal = pastTasks.filter { $0.assignedTo == name }.count
                    let memberRate = memberTotal > 0 ? Int(Double(memberDone) / Double(memberTotal) * 100) : 0
                    response += "• \(name): \(memberRate)% (\(memberDone)/\(memberTotal))\n"
                }
            }
        }

        let emoji = rate >= 80 ? "🎉" : rate >= 50 ? "👍" : "💪"
        response += "\n\(emoji) \(rate >= 80 ? "Great week!" : rate >= 50 ? "Solid effort!" : "Room to improve — you've got this!")"

        return (.weekSummary, response, nil, .none)
    }

    // MARK: - Task Status

    private func tryStatus(_ lower: String, _ original: String) -> (TaskIntent, String, TaskAction?, PendingContext)? {
        let statusPatterns = ["is", "has", "did", "status"]
        guard statusPatterns.contains(where: { lower.hasPrefix($0) }) || lower.contains("status") else { return nil }
        guard lower.contains("done") || lower.contains("complete") || lower.contains("finish") || lower.contains("status") else { return nil }

        let person = extractPerson(from: original)
        let taskName = extractTaskName(from: lower, excluding: ["is", "has", "did", "done", "complete", "finished", "status", "yet"])

        guard !taskName.isEmpty else {
            return (.status, "Which task are you checking on? Try something like \"Is Arya's homework done?\"", nil, .none)
        }

        var matching = allTasks.filter { $0.name.localizedCaseInsensitiveContains(taskName) && !$0.isArchived }
        if let person {
            matching = matching.filter { $0.assignedTo == person }
        }
        matching.sort { $0.targetDate > $1.targetDate }

        guard let task = matching.first else {
            return (.status, "I couldn't find a task matching \"\(taskName)\". It might be archived or the name could be different.", nil, .none)
        }

        let statusEmoji: String
        let statusText: String
        if task.isApproved { statusEmoji = "✅"; statusText = "Done" }
        else if task.isInReview { statusEmoji = "🟡"; statusText = "Waiting for approval" }
        else if task.isMissed { statusEmoji = "❌"; statusText = "Missed" }
        else if task.isCancelled { statusEmoji = "⬜"; statusText = "Cancelled" }
        else { statusEmoji = "🔵"; statusText = "Open — due \(task.targetDate.formatted(.dateTime.weekday(.abbreviated).hour().minute()))" }

        return (.status, "\(statusEmoji) **\(task.name)**\(task.assignedTo.isEmpty ? "" : " (\(task.assignedTo))")\nStatus: \(statusText)", nil, .none)
    }

    // MARK: - Helpers

    private var todayTasks: [Item] {
        allTasks.filter { Calendar.current.isDateInToday($0.targetDate) && !$0.isArchived }
    }

    private var todayAndFutureTasks: [Item] {
        let today = Calendar.current.startOfDay(for: Date())
        return allTasks.filter { $0.targetDate >= today && !$0.isArchived }
    }

    private var dateWords: [String] {
        ["today", "tomorrow", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
         "next", "this", "week", "morning", "afternoon", "evening", "night", "am", "pm"]
    }

    private func extractPerson(from text: String) -> String? {
        for member in familyMembers {
            let patterns = ["\(member)'s", "for \(member)", "\(member) ", "assign to \(member)"]
            for pattern in patterns {
                if text.range(of: pattern, options: .caseInsensitive) != nil {
                    return member
                }
            }
        }
        return nil
    }

    private func extractPersonFromQuery(from lower: String) -> String? {
        for member in familyMembers {
            if lower.contains(member.lowercased()) {
                return member
            }
        }
        if lower.contains("my ") || lower.contains("i ") || lower.contains("me") {
            return currentUser
        }
        return nil
    }

    private func extractDate(from lower: String) -> Date? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if lower.contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: today)!
        }

        let dayMap: [String: Int] = [
            "monday": 2, "tuesday": 3, "wednesday": 4, "thursday": 5,
            "friday": 6, "saturday": 7, "sunday": 1
        ]
        for (name, weekday) in dayMap {
            if lower.contains(name) {
                var comps = DateComponents()
                comps.weekday = weekday
                if let next = calendar.nextDate(after: today, matching: comps, matchingPolicy: .nextTime) {
                    return next
                }
            }
        }

        if lower.contains("next week") {
            return calendar.date(byAdding: .day, value: 7, to: today)!
        }

        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        if let match = detector?.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
           let date = match.date, date >= today {
            return date
        }

        return nil
    }

    private func extractTaskName(from lower: String, excluding: [String]) -> String {
        var text = lower

        for member in familyMembers {
            let memberPatterns = ["\(member.lowercased())'s", "for \(member.lowercased())", "\(member.lowercased())"]
            for pattern in memberPatterns {
                text = text.replacingOccurrences(of: pattern, with: "")
            }
        }

        for word in excluding + dateWords + ["to", "from", "the", "all", "my", "task", "tasks"] {
            text = text.replacingOccurrences(of: "\\b\(word)\\b", with: "", options: .regularExpression)
        }

        return text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ",.;:?!'\""))
            .trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Speech Manager

@Observable
final class SpeechManager {
    var isListening = false
    var transcribedText = ""
    private(set) var isAuthorized = false

    private var speechRecognizer = SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()

    func startListening() {
        if !isAuthorized {
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isAuthorized = (status == .authorized)
                    if status == .authorized {
                        self.beginRecording()
                    }
                }
            }
            return
        }
        beginRecording()
    }

    private func beginRecording() {
        guard let speechRecognizer, speechRecognizer.isAvailable, !isListening else { return }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let result {
                    self.transcribedText = result.bestTranscription.formattedString
                }
                if error != nil || (result?.isFinal ?? false) {
                    self.stopListening()
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
        } catch {
            stopListening()
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback, mode: .default, options: .duckOthers)
        try? audioSession.setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}

// MARK: - AI Assistant View

struct AIAssistantView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(SubscriptionManager.self) private var subscriptionManager
    let allTasks: [Item]
    let allMembers: [FamilyMember]
    let isIndividual: Bool
    var theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default")
    var isInline: Bool = false

    @State private var messages: [AIChatMessage] = []
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var pendingContext: PendingContext = .none
    @FocusState private var isInputFocused: Bool
    @State private var speechManager = SpeechManager()
    @State private var isVoiceOutputEnabled = false

    private var memberNames: [String] {
        var names = [authManager.userName]
        names += allMembers.filter { $0.name != authManager.userName }.map { $0.name }
        return names
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    messageList
                    inputBar
                }
            }
            .navigationTitle("AI Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        messages = []
                        pendingContext = .none
                        ChatMemory.clear()
                        addGreeting()
                    } label: {
                        Image(systemName: "trash")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isVoiceOutputEnabled.toggle()
                        if !isVoiceOutputEnabled {
                            speechManager.stopSpeaking()
                        }
                    } label: {
                        Image(systemName: isVoiceOutputEnabled ? "speaker.wave.2.fill" : "speaker.slash")
                            .font(.subheadline)
                            .foregroundStyle(isVoiceOutputEnabled ? calmAccent : .white.opacity(0.6))
                    }
                }
                if !isInline {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                            .foregroundStyle(.white)
                    }
                }
            }
            .onAppear {
                if messages.isEmpty {
                    let restored = ChatMemory.load()
                    if restored.isEmpty {
                        addGreeting()
                    } else {
                        messages = restored
                    }
                }
            }
            .onChange(of: messages.count) { _, _ in
                if isVoiceOutputEnabled, let last = messages.last, last.role == .assistant {
                    speechManager.speak(last.text)
                }
            }
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {

                    ForEach(messages) { message in
                        messageBubble(message)
                            .id(message.id)
                    }

                    if isProcessing {
                        HStack {
                            typingIndicator
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .id("typing")
                    }
                }
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _, _ in
                withAnimation {
                    if let lastId = messages.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    } else {
                        proxy.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var typingIndicator: some View {
        HStack(spacing: 4) {
            Text("Thinking...")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
            ProgressView()
                .tint(.white.opacity(0.5))
                .scaleEffect(0.7)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Message Bubble

    @ViewBuilder
    private func messageBubble(_ message: AIChatMessage) -> some View {
        let isUser = message.role == .user

        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(
                        isUser ? calmAccent.opacity(0.6) : .white.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 16)
                    )

                if let action = message.action, !action.isExecuted && !action.isCancelled {
                    actionCard(action, messageId: message.id)
                } else if let action = message.action, action.isExecuted {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Done!")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                    .padding(8)
                } else if let action = message.action, action.isCancelled {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.gray)
                        Text("Cancelled")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.gray)
                    }
                    .padding(8)
                }
            }

            if !isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Action Card

    private func actionCard(_ action: TaskAction, messageId: UUID) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: iconForIntent(action.intent))
                    .foregroundStyle(colorForIntent(action.intent))
                Text(action.summary)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }

            ForEach(action.details, id: \.self) { detail in
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }

            HStack(spacing: 12) {
                Button {
                    executeAction(action, messageId: messageId)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                        Text("Confirm")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.green, in: Capsule())
                }

                Button {
                    cancelAction(messageId: messageId)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                        Text("Cancel")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.15), in: Capsule())
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colorForIntent(action.intent).opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(colorForIntent(action.intent).opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask me anything...", text: $inputText)
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding(12)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )
                .focused($isInputFocused)
                .onSubmit { sendMessage() }
                .onChange(of: speechManager.transcribedText) { _, newText in
                    if speechManager.isListening && !newText.isEmpty {
                        inputText = newText
                    }
                }
                .onChange(of: isInputFocused) { _, focused in
                    if focused && speechManager.isListening {
                        speechManager.stopListening()
                    }
                }

            Button {
                toggleListening()
            } label: {
                Image(systemName: speechManager.isListening ? "mic.fill" : "mic")
                    .font(.system(size: 22))
                    .foregroundStyle(speechManager.isListening ? .red : .white.opacity(0.6))
            }

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? .white.opacity(0.3) : calmAccent)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isProcessing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.black.opacity(0.4))
    }

    // MARK: - Send & Process

    private func addGreeting() {
        let greeting: String
        if isIndividual {
            greeting = "Hi \(authManager.userName)! 👋 I'm your task assistant. I can create, reschedule, cancel, or check on your tasks — just tell me what you need!\n\nFor example:\n• \"Add grocery shopping tomorrow 10am\"\n• \"What do I have today?\"\n• \"Move my tasks to Saturday\""
        } else {
            let childNames = allMembers.filter { $0.isChild }.map { $0.name }
            let sampleName = childNames.first ?? authManager.userName
            greeting = "Hi \(authManager.userName)! 👋 I'm your family task assistant. I can create, reschedule, cancel, or check on tasks for anyone in the family.\n\nFor example:\n• \"Add homework for \(sampleName) tomorrow 5pm\"\n• \"What's \(sampleName) doing today?\"\n• \"How did the family do last week?\""
        }
        messages.append(AIChatMessage(role: .assistant, text: greeting))
        ChatMemory.save(messages)
    }

    private func saveChat() {
        ChatMemory.save(messages)
    }

    private func toggleListening() {
        if speechManager.isListening {
            speechManager.stopListening()
        } else {
            speechManager.transcribedText = ""
            speechManager.startListening()
        }
    }

    private func sendMessage() {
        if speechManager.isListening {
            speechManager.stopListening()
        }
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        messages.append(AIChatMessage(role: .user, text: text))
        inputText = ""
        isProcessing = true
        saveChat()

        Task {
            await sendViaClaude(text)
        }
    }

    private func selectModel(for message: String) -> String {
        let lower = message.lowercased()
        let actionKeywords = ["create", "add", "schedule", "reschedule", "cancel", "delete", "remove",
                              "assign", "update", "change", "move", "set", "mark", "complete", "done",
                              "pick up", "unassign", "recurring"]
        if actionKeywords.contains(where: { lower.contains($0) }) {
            return ClaudeAPIService.sonnetModel
        }
        return ClaudeAPIService.haikuModel
    }

    private func sendViaClaude(_ text: String) async {
        defer { isProcessing = false }

        guard subscriptionManager.canSendAIMessage() else {
            let remaining = subscriptionManager.maxAIMessagesPerMonth
            messages.append(AIChatMessage(role: .assistant, text: "You've reached your monthly AI message limit (\(remaining) messages). Upgrade your plan for more."))
            saveChat()
            return
        }

        let service = ClaudeAPIService.shared
        let model = selectModel(for: text)

        let filtered = messages
            .filter { $0.action == nil || $0.action?.isExecuted == true || $0.action?.isCancelled == true }
        let history = filtered
            .dropLast()
            .suffix(10)
            .map { (role: $0.role == .user ? "user" : "assistant", text: $0.text) }

        let tasksSummary = buildTasksSummary()

        do {
            let response = try await service.chat(
                userMessage: text,
                conversationHistory: Array(history),
                familyMembers: memberNames,
                currentUser: authManager.userName,
                isIndividual: isIndividual,
                tasksSummary: tasksSummary,
                model: model
            )

            subscriptionManager.recordAIMessage()

            if let parsedAction = response.action {
                let action = buildActionFromClaude(parsedAction)
                messages.append(AIChatMessage(role: .assistant, text: response.message, action: action))
            } else {
                messages.append(AIChatMessage(role: .assistant, text: response.message))
            }
            saveChat()
        } catch let apiError as ClaudeAPIService.APIError {
            switch apiError {
            case .httpError(let code, let body):
                let detail = body.prefix(200)
                messages.append(AIChatMessage(role: .assistant, text: "AI service error (\(code)): \(detail)"))
                fallbackToRuleParser(text)
            case .parseError:
                messages.append(AIChatMessage(role: .assistant, text: "Couldn't parse response. Using offline mode."))
                fallbackToRuleParser(text)
            }
            saveChat()
        } catch {
            messages.append(AIChatMessage(role: .assistant, text: "Connection error. Using offline mode."))
            fallbackToRuleParser(text)
            saveChat()
        }
    }

    private func fallbackToRuleParser(_ text: String) {
        let parser = TaskCommandParser(
            familyMembers: memberNames,
            currentUser: authManager.userName,
            allTasks: allTasks,
            isIndividual: isIndividual
        )
        let (_, response, action, newContext) = parser.parse(text, context: pendingContext)
        pendingContext = newContext
        messages.append(AIChatMessage(role: .assistant, text: response, action: action))
        saveChat()
    }

    private func buildTasksSummary() -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekAhead = calendar.date(byAdding: .day, value: 7, to: today)!

        let relevantTasks = allTasks.filter {
            !$0.isArchived && $0.targetDate >= calendar.date(byAdding: .day, value: -7, to: today)! && $0.targetDate < weekAhead
        }

        if relevantTasks.isEmpty { return "No tasks scheduled." }

        var lines: [String] = []
        for task in relevantTasks.prefix(30) {
            let status = task.isApproved ? "done" : task.isInReview ? "in-review" : task.isMissed ? "missed" : task.isCancelled ? "cancelled" : "open"
            let date = task.targetDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
            let who = task.assignedTo.isEmpty ? "" : " [\(task.assignedTo)]"
            let reward = task.reward > 0 ? " \(Int(task.reward))coins" : ""
            let recurring = task.isRecurring ? " [recurring]" : ""
            lines.append("- \(task.name)\(who) | \(date) | \(status)\(reward)\(recurring)")
        }
        if relevantTasks.count > 30 {
            lines.append("...and \(relevantTasks.count - 30) more tasks")
        }
        return lines.joined(separator: "\n")
    }

    private func buildActionFromClaude(_ parsed: ClaudeAPIService.ParsedAction) -> TaskAction? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoBasic = ISO8601DateFormatter()
        isoBasic.formatOptions = [.withInternetDateTime]
        let localDF = DateFormatter()
        localDF.locale = Locale(identifier: "en_US_POSIX")
        localDF.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        localDF.timeZone = TimeZone.current

        func parseDate(_ str: String?) -> Date? {
            guard let str else { return nil }
            // Prefer local time for strings without timezone indicator
            if !str.contains("Z") && !str.contains("+") {
                if let d = localDF.date(from: str) { return d }
            }
            // Fallback to UTC parsers for strings with timezone
            if let d = iso.date(from: str) { return d }
            if let d = isoBasic.date(from: str) { return d }
            // Last resort: try as local time even if other parsers failed
            return localDF.date(from: str)
        }

        switch parsed.intent {
        case "create":
            guard let name = parsed.taskName, !name.isEmpty else { return nil }
            let assignee = parsed.assignee ?? authManager.userName
            let date = parseDate(parsed.date) ?? Date()
            let reward = parsed.reward ?? 0

            let recurrenceStr = (parsed.recurrence ?? "none").lowercased()
            let recurrenceType: RecurrenceType = switch recurrenceStr {
                case "daily": .daily
                case "weekly": .weekly
                case "monthly": .monthly
                default: .none
            }
            let defaultOccurrences: Int = switch recurrenceType {
                case .daily: 7
                case .weekly: 4
                case .monthly: 3
                case .none: 1
            }
            let occurrences = parsed.occurrences ?? defaultOccurrences

            var details = [name]
            details.append("📅 \(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().hour().minute()))")
            details.append("👤 \(assignee)")
            if reward > 0 { details.append("⭐ \(reward) coins") }
            if recurrenceType != .none {
                details.append("🔄 \(recurrenceType.rawValue) × \(occurrences) instances")
            }

            var parsedTask = ParsedTask()
            parsedTask.name = name
            parsedTask.targetDate = date
            parsedTask.assignedTo = assignee
            parsedTask.reward = reward
            parsedTask.recurrence = recurrenceType
            parsedTask.occurrences = occurrences

            let summary = recurrenceType != .none ? "Create recurring task (\(occurrences)×)" : "Create new task"
            var action = TaskAction(intent: .create, summary: summary, details: details)
            action.parsedTask = parsedTask
            action.newAssignee = assignee
            return action

        case "reschedule":
            let matchNames = parsed.matchingTaskNames ?? [parsed.taskName].compactMap { $0 }
            let newDate = parseDate(parsed.newDate)
            guard let newDate, !matchNames.isEmpty else { return nil }

            let scope = parsed.rescheduleScope ?? "instance"
            let timeComps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
            let hasExplicitTime = (timeComps.hour ?? 0) != 0 || (timeComps.minute ?? 0) != 0
            let preserveTime = parsed.preserveTime && !hasExplicitTime

            var matching = allTasks.filter { task in
                task.isOpen && matchNames.contains(where: { task.name.localizedCaseInsensitiveContains($0) })
            }

            if scope == "series" {
                let seriesNames = Set(matching.map { $0.name })
                let seriesAssignees = Set(matching.map { $0.assignedTo })
                let seriesTasks = allTasks.filter { task in
                    task.isOpen && task.isRecurring &&
                    seriesNames.contains(task.name) &&
                    seriesAssignees.contains(task.assignedTo) &&
                    !matching.contains(where: { $0.id == task.id })
                }
                matching.append(contentsOf: seriesTasks)
            }

            guard !matching.isEmpty else { return nil }

            let timeFormat = preserveTime
                ? newDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
                : newDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
            let details = matching.map { "\($0.emoji) \($0.name) → \(timeFormat)" }
            let scopeLabel = scope == "series" ? " (entire series)" : ""
            var action = TaskAction(intent: .reschedule, summary: "Reschedule \(matching.count) task\(matching.count == 1 ? "" : "s")\(scopeLabel)", details: details, tasks: matching, newDate: newDate)
            action.preserveTime = preserveTime
            action.rescheduleScope = scope
            return action

        case "cancel":
            let matchNames = parsed.matchingTaskNames ?? [parsed.taskName].compactMap { $0 }
            guard !matchNames.isEmpty else { return nil }

            let cancelScope = parsed.rescheduleScope ?? "instance"

            var matching = allTasks.filter { task in
                task.isOpen && matchNames.contains(where: { task.name.localizedCaseInsensitiveContains($0) })
            }

            if cancelScope == "series" {
                let seriesNames = Set(matching.map { $0.name })
                let seriesAssignees = Set(matching.map { $0.assignedTo })
                let seriesTasks = allTasks.filter { task in
                    task.isOpen && task.isRecurring &&
                    seriesNames.contains(task.name) &&
                    seriesAssignees.contains(task.assignedTo) &&
                    !matching.contains(where: { $0.id == task.id })
                }
                matching.append(contentsOf: seriesTasks)
            }

            guard !matching.isEmpty else { return nil }

            let scopeLabel = cancelScope == "series" ? " (entire series)" : ""
            let details = matching.map { "\($0.emoji) \($0.name)\($0.assignedTo.isEmpty ? "" : " (\($0.assignedTo))")" }
            var action = TaskAction(intent: .cancel, summary: "Cancel \(matching.count) task\(matching.count == 1 ? "" : "s")\(scopeLabel)", details: details, tasks: matching)
            action.rescheduleScope = cancelScope
            return action

        case "markDone":
            let matchNames = parsed.matchingTaskNames ?? [parsed.taskName].compactMap { $0 }
            guard !matchNames.isEmpty else { return nil }

            let matching = allTasks.filter { task in
                (task.isOpen || task.isInReview) && matchNames.contains(where: { task.name.localizedCaseInsensitiveContains($0) })
            }
            guard !matching.isEmpty else { return nil }

            let details = matching.map { "\($0.emoji) \($0.name)\($0.assignedTo.isEmpty ? "" : " (\($0.assignedTo))")" }
            return TaskAction(intent: .markDone, summary: "Mark \(matching.count) task\(matching.count == 1 ? "" : "s") as done", details: details, tasks: matching)

        default:
            return nil
        }
    }

    // MARK: - Execute Actions

    private func executeAction(_ action: TaskAction, messageId: UUID) {
        switch action.intent {
        case .reschedule:
            executeReschedule(action, messageId: messageId)
        case .cancel:
            executeCancelTasks(action, messageId: messageId)
        case .markDone:
            executeMarkDone(action, messageId: messageId)
        case .create:
            executeCreate(action, messageId: messageId)
        default:
            break
        }
    }

    private func executeReschedule(_ action: TaskAction, messageId: UUID) {
        guard let newDate = action.newDate else {
            messages.append(AIChatMessage(role: .assistant, text: "Something went wrong — no target date was set. Please try again."))
            return
        }

        var rescheduled = 0
        var failed = 0

        let calendar = Calendar.current
        let newTimeComponents = calendar.dateComponents([.hour, .minute], from: newDate)

        for task in action.tasks {
            guard task.isOpen else {
                failed += 1
                continue
            }

            let finalDate: Date
            if action.preserveTime {
                let origTime = calendar.dateComponents([.hour, .minute], from: task.targetDate)
                var d = calendar.startOfDay(for: newDate)
                d = calendar.date(bySettingHour: origTime.hour ?? 0, minute: origTime.minute ?? 0, second: 0, of: d)!
                finalDate = d
            } else {
                var d = calendar.startOfDay(for: newDate)
                d = calendar.date(bySettingHour: newTimeComponents.hour ?? 0, minute: newTimeComponents.minute ?? 0, second: 0, of: d)!
                finalDate = d
            }

            task.targetDate = finalDate
            notificationManager.cancelTaskReminder(taskId: task.id)
            notificationManager.scheduleTaskReminder(taskId: task.id, taskName: task.name, assignedTo: task.assignedTo, dueDate: finalDate)
            rescheduled += 1
        }

        try? modelContext.save()

        let familyCode = authManager.familyCode
        let snapshots = action.tasks.filter { $0.isOpen || rescheduled > 0 }.map { CloudKitManager.TaskSnapshot($0) }
        Task {
            for snap in snapshots {
                await cloudKitManager.pushTaskSnapshot(snap, familyCode: familyCode)
            }
        }

        markActionExecuted(messageId: messageId)

        let dateFormat = action.preserveTime
            ? newDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
            : newDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().hour().minute())
        let scopeNote = action.rescheduleScope == "series" ? " (entire series)" : ""
        var response = "✅ Done! \(rescheduled) task\(rescheduled == 1 ? "" : "s") rescheduled to \(dateFormat)\(scopeNote)."
        if failed > 0 {
            response += " \(failed) task\(failed == 1 ? " was" : "s were") skipped (no longer open)."
        }
        messages.append(AIChatMessage(role: .assistant, text: response))
    }

    private func executeCancelTasks(_ action: TaskAction, messageId: UUID) {
        var cancelled = 0
        var deleted = 0
        var skipped = 0
        let isSeries = action.rescheduleScope == "series"

        if isSeries {
            let toDelete = action.tasks.filter { !$0.isApproved && !$0.isInReview }
            var taskIDs: [UUID] = []
            for task in toDelete {
                notificationManager.cancelTaskReminder(taskId: task.id)
                taskIDs.append(task.id)
                withAnimation { modelContext.delete(task) }
                deleted += 1
            }
            skipped = action.tasks.count - toDelete.count
            try? modelContext.save()
            let familyCode = authManager.familyCode
            Task { await cloudKitManager.deleteRemoteTasks(taskIDs) }
        } else {
            for task in action.tasks {
                guard task.isOpen else {
                    skipped += 1
                    continue
                }
                task.status = "cancelled"
                notificationManager.cancelTaskReminder(taskId: task.id)
                cancelled += 1
            }
            try? modelContext.save()
            let familyCode = authManager.familyCode
            let snapshots = action.tasks.map { CloudKitManager.TaskSnapshot($0) }
            Task {
                for snap in snapshots {
                    await cloudKitManager.pushTaskSnapshot(snap, familyCode: familyCode)
                }
            }
        }

        markActionExecuted(messageId: messageId)

        if isSeries {
            var response = "✅ \(deleted) recurring task\(deleted == 1 ? "" : "s") deleted."
            if skipped > 0 {
                response += " \(skipped) completed task\(skipped == 1 ? "" : "s") preserved with coins."
            }
            messages.append(AIChatMessage(role: .assistant, text: response))
        } else {
            var response = "✅ \(cancelled) task\(cancelled == 1 ? "" : "s") cancelled."
            if skipped > 0 {
                response += " \(skipped) task\(skipped == 1 ? " was" : "s were") already completed or cancelled."
            }
            messages.append(AIChatMessage(role: .assistant, text: response))
        }
    }

    private func executeMarkDone(_ action: TaskAction, messageId: UUID) {
        var completed = 0
        var skipped = 0

        for task in action.tasks {
            guard task.isOpen || task.isInReview else {
                skipped += 1
                continue
            }
            task.status = "approved"
            notificationManager.cancelTaskReminder(taskId: task.id)
            completed += 1
        }

        try? modelContext.save()

        let familyCode = authManager.familyCode
        let snapshots = action.tasks.map { CloudKitManager.TaskSnapshot($0) }
        Task {
            for snap in snapshots {
                await cloudKitManager.pushTaskSnapshot(snap, familyCode: familyCode)
            }
        }

        markActionExecuted(messageId: messageId)

        let coinsEarned = action.tasks.filter { $0.isApproved && $0.reward > 0 }.reduce(0) { $0 + Int($1.reward) }
        var response = "✅ \(completed) task\(completed == 1 ? "" : "s") marked as done!"
        if coinsEarned > 0 { response += " \(coinsEarned) coins earned ⭐" }
        if skipped > 0 {
            response += " \(skipped) task\(skipped == 1 ? " was" : "s were") already completed."
        }
        messages.append(AIChatMessage(role: .assistant, text: response))
    }

    private func executeCreate(_ action: TaskAction, messageId: UUID) {
        guard let parsed = action.parsedTask else {
            messages.append(AIChatMessage(role: .assistant, text: "Something went wrong — task details were missing. Please try creating the task again."))
            return
        }

        let assignee = action.newAssignee ?? authManager.userName

        if !subscriptionManager.canCreateMoreTasks(allTasks: allTasks) {
            markActionExecuted(messageId: messageId)
            messages.append(AIChatMessage(role: .assistant, text: "You've reached the task limit for this month. Upgrade your plan to create more tasks."))
            return
        }

        if !subscriptionManager.canCreateTask {
            markActionExecuted(messageId: messageId)
            messages.append(AIChatMessage(role: .assistant, text: "Please wait a few seconds before creating another task."))
            return
        }

        let isRecurring = parsed.recurrence != .none
        let dates = generateRecurringDates(startDate: parsed.targetDate, recurrence: parsed.recurrence, occurrences: parsed.occurrences)

        var createdTasks: [Item] = []
        for date in dates {
            let task = Item(
                name: parsed.name,
                targetDate: date,
                assignedTo: assignee,
                reward: Double(parsed.reward),
                isRecurring: isRecurring,
                createdBy: authManager.userName,
                createdByID: authManager.appleUserID
            )
            modelContext.insert(task)
            createdTasks.append(task)
            subscriptionManager.recordTaskCreation()
            notificationManager.scheduleTaskReminder(taskId: task.id, taskName: task.name, assignedTo: assignee, dueDate: date)
        }
        try? modelContext.save()

        let familyCode = authManager.familyCode
        Task {
            for task in createdTasks {
                await cloudKitManager.pushTask(task, familyCode: familyCode)
            }
        }

        markActionExecuted(messageId: messageId)

        if isRecurring {
            let lastDate = dates.last ?? parsed.targetDate
            var response = "✅ \(createdTasks.count) \"\(parsed.name)\" tasks created!\n\n"
            response += "🔄 \(parsed.recurrence.rawValue) from \(parsed.targetDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())) to \(lastDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))\n"
            response += "⏰ \(parsed.targetDate.formatted(.dateTime.hour().minute()))\n"
            response += "👤 Assigned to \(assignee)"
            if parsed.reward > 0 { response += "\n⭐ \(parsed.reward) coins each" }
            response += "\n\nAll \(createdTasks.count) tasks are live with reminders set."
            messages.append(AIChatMessage(role: .assistant, text: response))
        } else {
            var response = "✅ \"\(parsed.name)\" has been created!\n\n"
            response += "📅 \(parsed.targetDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().hour().minute()))\n"
            response += "👤 Assigned to \(assignee)"
            if parsed.reward > 0 { response += "\n⭐ \(parsed.reward) coins reward" }
            response += "\n\nThe task is now live and a reminder has been set."
            messages.append(AIChatMessage(role: .assistant, text: response))
        }
    }

    private func generateRecurringDates(startDate: Date, recurrence: RecurrenceType, occurrences: Int) -> [Date] {
        let calendar = Calendar.current
        switch recurrence {
        case .none:
            return [startDate]
        case .daily:
            return (0..<occurrences).compactMap { i in
                calendar.date(byAdding: .day, value: i, to: startDate)
            }
        case .weekly:
            return (0..<occurrences).compactMap { i in
                calendar.date(byAdding: .weekOfYear, value: i, to: startDate)
            }
        case .monthly:
            return (0..<occurrences).compactMap { i in
                calendar.date(byAdding: .month, value: i, to: startDate)
            }
        }
    }

    private func cancelAction(messageId: UUID) {
        if let idx = messages.firstIndex(where: { $0.id == messageId }) {
            messages[idx].action?.isCancelled = true
        }
        pendingContext = .none
        messages.append(AIChatMessage(role: .assistant, text: "No problem, I've cancelled that. What else can I help with?"))
        saveChat()
    }

    private func markActionExecuted(messageId: UUID) {
        if let idx = messages.firstIndex(where: { $0.id == messageId }) {
            messages[idx].action?.isExecuted = true
        }
        saveChat()
    }

    // MARK: - Helpers

    private func iconForIntent(_ intent: TaskIntent) -> String {
        switch intent {
        case .create: return "plus.circle.fill"
        case .reschedule: return "calendar.badge.clock"
        case .cancel: return "xmark.circle.fill"
        case .markDone: return "checkmark.circle.fill"
        default: return "sparkles"
        }
    }

    private func colorForIntent(_ intent: TaskIntent) -> Color {
        switch intent {
        case .create: return .blue
        case .reschedule: return .orange
        case .cancel: return .red
        case .markDone: return .green
        default: return .purple
        }
    }
}
