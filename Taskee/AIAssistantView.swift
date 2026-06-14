//
//  AIAssistantView.swift
//  Taskee
//

import SwiftUI
import SwiftData
import Speech
import AVFoundation

// MARK: - Tiled Logo Background

struct TiledLogoBackground: View {
    let tileSize: CGFloat = 36
    let spacing: CGFloat = 30

    private var appIcon: UIImage? {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let name = files.last {
            return UIImage(named: name)
        }
        return UIImage(named: "AppIcon")
    }

    var body: some View {
        GeometryReader { geo in
            if let icon = appIcon {
                let step = tileSize + spacing
                let cols = Int(geo.size.width / step) + 2
                let rows = Int(geo.size.height / step) + 2

                ForEach(0..<rows, id: \.self) { row in
                    ForEach(0..<cols, id: \.self) { col in
                        let offset = row.isMultiple(of: 2) ? 0 : step / 2
                        Image(uiImage: icon)
                            .resizable()
                            .frame(width: tileSize, height: tileSize)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .opacity(0.2)
                            .rotationEffect(.degrees(-15))
                            .position(
                                x: CGFloat(col) * step + offset,
                                y: CGFloat(row) * step
                            )
                    }
                }
            }
        }
    }
}

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
        let tasks: [[String: Any]]?
        let newName: String?
        let newReward: Int?
        let newAssignee: String?
        // Goal fields
        let goalName: String?
        let goalTemplateId: String?
        let assignees: [String]?
        let category: String?
        let durationDays: Int?
        let isCustomGoal: Bool?
        let goalTasks: [[String: Any]]?
        // Shopping & wish list fields
        let itemNames: [String]?
        // Project fields
        let projectName: String?
        let projectDescription: String?
        let projectCategory: String?
        let projectStatus: String?
        let ideaText: String?
        // Reminder fields
        let reminderScope: String?
    }

    func chat(
        userMessage: String,
        conversationHistory: [(role: String, text: String)],
        familyMembers: [String],
        currentUser: String,
        isIndividual: Bool,
        tasksSummary: String,
        insightsSummary: String = "",
        goalCatalogSummary: String = "",
        model: String = ClaudeAPIService.sonnetModel,
        isVoiceMode: Bool = false
    ) async throws -> ClaudeResponse {
        let systemPrompt = buildSystemPrompt(
            familyMembers: familyMembers,
            currentUser: currentUser,
            isIndividual: isIndividual,
            tasksSummary: tasksSummary,
            insightsSummary: insightsSummary,
            goalCatalogSummary: goalCatalogSummary,
            isVoiceMode: isVoiceMode
        )

        var apiMessages: [[String: String]] = []
        for entry in conversationHistory.suffix(10) {
            apiMessages.append(["role": entry.role, "content": entry.text])
        }
        apiMessages.append(["role": "user", "content": userMessage])

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1536,
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

    private func buildSystemPrompt(familyMembers: [String], currentUser: String, isIndividual: Bool, tasksSummary: String, insightsSummary: String = "", goalCatalogSummary: String = "", isVoiceMode: Bool = false) -> String {
        let memberList = familyMembers.joined(separator: ", ")
        let now = Date()
        let today = now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year())
        let currentTime = now.formatted(.dateTime.hour().minute())
        let timezone = TimeZone.current.identifier

        var prompt = """
        You are a helpful family task management assistant in the Taskoot app. Today is \(today), current time is \(currentTime) (\(timezone)).
        Current user: \(currentUser). \(isIndividual ? "This user manages tasks individually (no family)." : "Family members: \(memberList).")

        CURRENT TASKS:
        \(tasksSummary)
        """

        if !insightsSummary.isEmpty {
            prompt += "\n\n\(insightsSummary)"
        }

        if !goalCatalogSummary.isEmpty {
            prompt += "\n\n\(goalCatalogSummary)"
        }

        prompt += """


        You help users create, reschedule, update, cancel, complete tasks, and set goals. You also answer questions about task status, coins earned, weekly summaries, and goal suggestions.

        RESPONSE FORMAT — you MUST respond with valid JSON only, no extra text:
        {
            "message": "Your conversational response to the user",
            "action": null or {
                "intent": "create|reschedule|cancel|markDone|update|setGoal|deleteGoal|pauseGoal|resumeGoal|completeGoal|addToCart|removeFromCart|markBought|addToWishList|removeFromWishList|createProject|editProject|deleteProject|updateProjectStatus|addProjectIdea|sendReminder",

                // Task fields (create/reschedule/cancel/markDone/update)
                "taskName": "string or null",
                "assignee": "string or null",
                "date": "ISO 8601 datetime or null",
                "reward": "number or null",
                "matchingTaskNames": ["names"] or null,
                "newDate": "ISO 8601 datetime or null",
                "preserveTime": true/false,
                "rescheduleScope": "instance|series",
                "recurrence": "none|daily|weekly|monthly",
                "occurrences": "number or null",
                "newName": "string or null",
                "newReward": "number or null",
                "newAssignee": "string or null",
                "tasks": [{"taskName":"","assignee":"","date":"","reward":0,"recurrence":"","occurrences":0}] or null,

                // Goal fields (setGoal)
                "goalName": "string or null",
                "goalTemplateId": "string or null",
                "assignees": ["names"] or null,
                "category": "string or null",
                "durationDays": "number or null",
                "isCustom": true/false,
                "goalTasks": [{"taskName":"","frequency":"","occurrences":0,"reward":0,"hour":0,"minute":0}] or null,

                // Shopping & wish list fields
                "itemNames": ["item1", "item2"] or null,

                // Project fields
                "projectName": "string or null",
                "projectDescription": "string or null",
                "projectCategory": "string or null",
                "projectStatus": "ideating|planning|inProgress|completed",
                "ideaText": "string or null",
                "reminderScope": "today or null"
            }
        }

        RULES:
        - Set "action" to null for questions, status checks, summaries, clarifications, or when information is missing.
        - IMPORTANT: For ANY action that modifies data, you MUST include the "action" object so the user sees a preview and can confirm. Never just describe what you would do — always provide the action.
        - For "create": require at minimum a task name. If assignee is missing\(isIndividual ? ", default to \(currentUser)" : " and there are multiple family members, ask who to assign to"). If date is missing, default to today.
          - Recurring: set "recurrence" + "occurrences". Defaults: daily=7, weekly=4, monthly=3.
          - Multi-task: use "tasks" array. Each entry has own name, assignee, date, reward, recurrence, occurrences.
        - For "setGoal": structured goal with recurring tasks. Use "goalTemplateId" for template, or "" + "isCustom":true for custom.
          - Adjust task parameters based on MEMBER INSIGHTS. Max 3 active goals per member.
          - "category": Education|Well-being|Lifestyle|Finance|Skills|Fitness. "durationDays": default 30.
        - For "reschedule": "matchingTaskNames" + "newDate". Set "preserveTime":true if only date changes, false if time specified. Ask about "rescheduleScope" for recurring tasks.
        - For "update": "matchingTaskNames" + "newName"/"newReward"/"newAssignee". Ask about scope for recurring.
        - For "cancel"/"markDone": "matchingTaskNames". Ask about scope for recurring.

        GOAL MANAGEMENT:
        - "deleteGoal": delete a goal and its open tasks. Use "goalName" to match. Match against CURRENT GOALS data.
        - "pauseGoal": pause an active goal. Use "goalName".
        - "resumeGoal": resume a paused goal. Use "goalName".
        - "completeGoal": mark goal as completed. Use "goalName".

        SHOPPING LIST:
        - "addToCart": add items. Use "itemNames" array with item names to add.
        - "removeFromCart": remove items. Use "itemNames" to match existing items.
        - "markBought": toggle bought status. Use "itemNames" to match.

        WISH LIST:
        - "addToWishList": add items. Use "itemNames" array.
        - "removeFromWishList": remove items. Use "itemNames" to match.

        PROJECTS:
        - "createProject": create a family project. Use "projectName", "projectDescription" (optional), "projectCategory" (one of: Home, Travel, Pet, Fitness, Education, Fun, Finance).
        - "editProject": modify project. Use "projectName" to match, plus "newName"/"projectDescription"/"projectCategory" for changes.
        - "deleteProject": delete a project. Use "projectName" to match.
        - "updateProjectStatus": change status. Use "projectName" + "projectStatus" (ideating→planning→inProgress→completed).
        - "addProjectIdea": submit an idea to a project. Use "projectName" to match + "ideaText".

        REMINDERS (parent mode only):
        - "sendReminder": send a reminder notification to a family member for their tasks. Use "matchingTaskNames" to specify tasks, OR set "reminderScope" to "today" to remind about all of today's open tasks. Optionally use "assignee" to target a specific member.
        - This pushes a notification to the member's device. Only available for parents.

        GENERAL:
        - Be conversational, friendly, and concise. Ask clarifying questions when ambiguous.
        - ALL dates MUST be ISO 8601 in LOCAL time WITHOUT timezone suffix (e.g. "2026-06-14T19:00:00").
        - ALWAYS respond with valid JSON only. No markdown, backticks, or text outside the JSON.
        - When the user says goodbye, thanks, or indicates they're done (e.g. "bye", "thanks", "I'm good", "that's all"), respond warmly and briefly. Mention they can tap the mic anytime to start voice mode again. Do NOT include an action for farewell messages.
        \(isVoiceMode ? """

        VOICE MODE (ACTIVE):
        - The user is speaking via voice. Keep responses SHORT — 1-2 sentences max. No lists, no bullet points, no long explanations.
        - For actions: describe what you'll do in one brief sentence, include the action object, and end with "Shall I go ahead?" so the user can confirm vocally.
        - For status/summary questions: give a brief spoken-friendly answer. Say numbers naturally (e.g. "You have 3 tasks today, 2 are done").
        - Avoid emojis and special formatting — your response will be read aloud.
        """ : "")
        """
        return prompt
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
                occurrences: actionJson["occurrences"] as? Int,
                tasks: actionJson["tasks"] as? [[String: Any]],
                newName: actionJson["newName"] as? String,
                newReward: actionJson["newReward"] as? Int,
                newAssignee: actionJson["newAssignee"] as? String,
                goalName: actionJson["goalName"] as? String,
                goalTemplateId: actionJson["goalTemplateId"] as? String,
                assignees: actionJson["assignees"] as? [String],
                category: actionJson["category"] as? String,
                durationDays: actionJson["durationDays"] as? Int,
                isCustomGoal: actionJson["isCustom"] as? Bool,
                goalTasks: actionJson["goalTasks"] as? [[String: Any]],
                itemNames: actionJson["itemNames"] as? [String],
                projectName: actionJson["projectName"] as? String,
                projectDescription: actionJson["projectDescription"] as? String,
                projectCategory: actionJson["projectCategory"] as? String,
                projectStatus: actionJson["projectStatus"] as? String,
                ideaText: actionJson["ideaText"] as? String,
                reminderScope: actionJson["reminderScope"] as? String
            )
        }

        return ClaudeResponse(message: message, action: parsedAction)
    }

    // MARK: - Goal Task Generation

    func generateGoalTasks(
        goalName: String,
        audience: GoalAudience,
        durationDays: Int,
        memberInsight: String = ""
    ) async throws -> GoalSuggestion {
        let audienceDesc: String = switch audience {
        case .child: "a child (use simple, encouraging language and age-appropriate tasks)"
        case .parent: "a parent/adult managing family tasks"
        case .individual: "an individual adult"
        }

        var prompt = """
        Generate 4-5 practical, actionable tasks for this goal. Each task should be something the person does regularly to achieve the goal.

        Goal: "\(goalName)"
        Audience: \(audienceDesc)
        Duration: \(durationDays) days

        """

        if !memberInsight.isEmpty {
            prompt += "\nUser context:\n\(memberInsight)\n"
        }

        prompt += """

        Respond with ONLY valid JSON (no markdown, no backticks, no extra text):
        {
            "category": "Education|Well-being|Lifestyle|Finance|Skills|Fitness",
            "icon": "SF Symbol name (e.g. book.fill, figure.run, heart.fill)",
            "tasks": [
                {
                    "taskName": "specific actionable task",
                    "frequency": "daily|weekly|monthly",
                    "occurrences": number,
                    "reward": number (1-5 based on effort),
                    "hour": number (0-23, sensible time for this activity),
                    "minute": 0
                }
            ]
        }

        Guidelines:
        - Each task must be specific and actionable (not vague like "work on goal")
        - Mix daily habits (3-4) with weekly tasks (1-2) for variety
        - Daily occurrences: roughly match duration days (e.g. 25-30 for a 30-day goal)
        - Weekly occurrences: duration/7 rounded (e.g. 4 for 30 days)
        - Rewards: 1-2 for easy daily tasks, 3-5 for harder weekly tasks
        - Schedule times that make sense (exercise=morning, reading=evening, etc.)
        - Pick the single best matching category
        - Use a relevant SF Symbol icon name
        """

        let body: [String: Any] = [
            "model": ClaudeAPIService.haikuModel,
            "max_tokens": 1024,
            "system": prompt,
            "messages": [["role": "user", "content": "Generate tasks for this goal."]]
        ]

        var request = URLRequest(url: proxyURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(appToken, forHTTPHeaderField: "X-App-Token")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 20

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

        return parseGoalSuggestion(text, durationDays: durationDays)
    }

    private func parseGoalSuggestion(_ text: String, durationDays: Int) -> GoalSuggestion {
        var jsonText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let codeStart = jsonText.range(of: "```(?:json)?\\s*", options: .regularExpression),
           let codeEnd = jsonText.range(of: "```", options: .backwards, range: codeStart.upperBound..<jsonText.endIndex) {
            jsonText = String(jsonText[codeStart.upperBound..<codeEnd.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if !jsonText.hasPrefix("{"),
           let start = jsonText.firstIndex(of: "{"),
           let end = jsonText.lastIndex(of: "}") {
            jsonText = String(jsonText[start...end])
        }

        guard let data = jsonText.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tasksArray = json["tasks"] as? [[String: Any]], !tasksArray.isEmpty else {
            // Return a sensible fallback
            return GoalSuggestion(category: .lifestyle, icon: "star.fill", durationDays: durationDays, tasks: [])
        }

        let categoryStr = (json["category"] as? String ?? "Lifestyle").lowercased().replacingOccurrences(of: "-", with: "")
        let category = GoalCategory.allCases.first { $0.rawValue.lowercased() == categoryStr }
            ?? GoalCategory.allCases.first { categoryStr.contains($0.rawValue.lowercased()) }
            ?? .lifestyle
        let icon = json["icon"] as? String ?? category.icon

        var entries: [GoalTaskEntry] = []
        for taskDict in tasksArray {
            guard let name = taskDict["taskName"] as? String, !name.isEmpty else { continue }
            let freqStr = (taskDict["frequency"] as? String ?? "daily").lowercased()
            let freq: RecurrenceType = switch freqStr {
            case "weekly": .weekly
            case "monthly": .monthly
            default: .daily
            }
            let occ = taskDict["occurrences"] as? Int ?? (freq == .daily ? durationDays : freq == .weekly ? max(durationDays / 7, 1) : max(durationDays / 30, 1))
            let reward = taskDict["reward"] as? Int ?? 2
            let hour = taskDict["hour"] as? Int ?? 9
            let minute = taskDict["minute"] as? Int ?? 0
            entries.append(GoalTaskEntry(name: name, frequency: freq, occurrences: occ, reward: reward, hour: hour, minute: minute))
        }

        return GoalSuggestion(category: category, icon: icon, durationDays: durationDays, tasks: entries)
    }

    // MARK: - Goal Task Refinement

    func refineGoalTasks(
        goalName: String,
        audience: GoalAudience,
        durationDays: Int,
        currentTasks: [GoalTaskEntry],
        userFeedback: String
    ) async throws -> GoalSuggestion {
        let audienceDesc: String = switch audience {
        case .child: "a child (use simple, encouraging language and age-appropriate tasks)"
        case .parent: "a parent/adult managing family tasks"
        case .individual: "an individual adult"
        }

        let tasksJSON = currentTasks.map { task in
            "- \(task.name) (\(task.frequency.rawValue), x\(task.occurrences), reward:\(task.reward))"
        }.joined(separator: "\n")

        let prompt = """
        You previously suggested tasks for a goal. The user wants changes. Update the task list based on their feedback.

        Goal: "\(goalName)"
        Audience: \(audienceDesc)
        Duration: \(durationDays) days

        Current tasks:
        \(tasksJSON)

        User feedback: "\(userFeedback)"

        Respond with ONLY valid JSON (no markdown, no backticks, no extra text):
        {
            "category": "Education|Well-being|Lifestyle|Finance|Skills|Fitness",
            "icon": "SF Symbol name",
            "tasks": [
                {
                    "taskName": "specific actionable task",
                    "frequency": "daily|weekly|monthly",
                    "occurrences": number,
                    "reward": number (1-5),
                    "hour": number (0-23),
                    "minute": 0
                }
            ]
        }

        Apply the user's feedback precisely. Keep unchanged tasks as-is. Return the full updated list.
        """

        let body: [String: Any] = [
            "model": ClaudeAPIService.haikuModel,
            "max_tokens": 1024,
            "system": prompt,
            "messages": [["role": "user", "content": "Refine the tasks based on my feedback."]]
        ]

        var request = URLRequest(url: proxyURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(appToken, forHTTPHeaderField: "X-App-Token")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 20

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

        return parseGoalSuggestion(text, durationDays: durationDays)
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

struct GoalTaskEntry {
    var name: String
    var frequency: RecurrenceType
    var occurrences: Int
    var reward: Int
    var hour: Int
    var minute: Int
}

struct GoalSuggestion {
    let category: GoalCategory
    let icon: String
    let durationDays: Int
    let tasks: [GoalTaskEntry]
}

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
    var newName: String?
    var newReward: Int?
    var parsedTask: ParsedTask?
    var parsedTasks: [ParsedTask] = []
    var preserveTime: Bool = true
    var rescheduleScope: String = "instance"

    // Goal fields
    var goalName: String?
    var goalTemplateId: String?
    var goalCategory: String?
    var goalDurationDays: Int?
    var goalIsCustom: Bool = false
    var goalAssignees: [String] = []
    var goalTasks: [GoalTaskEntry] = []
    // Shopping & wish list
    var itemNames: [String] = []
    // Project fields
    var projectName: String?
    var projectDescription: String?
    var projectCategory: String?
    var projectStatus: String?
    var ideaText: String?
    var reminderScope: String?
    var matchingGoals: [Goal] = []
    var matchingShoppingItems: [ShoppingItem] = []
    var matchingWishListItems: [WishListItem] = []
    var matchingProjects: [FamilyProject] = []
}

// MARK: - Task Intent

enum TaskIntent {
    case create
    case reschedule
    case cancel
    case markDone
    case update
    case setGoal
    // Goal management
    case deleteGoal
    case pauseGoal
    case resumeGoal
    case completeGoal
    // Shopping list
    case addToCart
    case removeFromCart
    case markBought
    // Wish list
    case addToWishList
    case removeFromWishList
    // Projects
    case createProject
    case editProject
    case deleteProject
    case updateProjectStatus
    case addProjectIdea
    // Reminders
    case sendReminder
    // Informational
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
        if let result = trySetGoal(lower, input) { return result }
        if let result = tryCreate(lower, input) { return result }
        if let result = tryListTasks(lower) { return result }
        if let result = tryCheckCoins(lower) { return result }
        if let result = tryWeekSummary(lower) { return result }
        if let result = tryStatus(lower, input) { return result }

        return (.unknown, "I didn't quite catch that. Here's what I can help with:\n\n• Create tasks — \"Add homework for Arya tomorrow 5pm\"\n• Set goals — \"Set a reading goal for Arya\"\n• Reschedule — \"Move today's tasks to Saturday\"\n• Cancel or complete — \"Cancel swimming\" / \"Mark reading as done\"\n• Check status — \"What's Arya doing today?\"\n• Summaries — \"How did we do last week?\"", nil, .none)
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

    // MARK: - Set Goal (offline)

    private func trySetGoal(_ lower: String, _ original: String) -> (TaskIntent, String, TaskAction?, PendingContext)? {
        let goalPatterns = ["set a goal", "set goal", "create a goal", "create goal", "start a goal", "start goal",
                            "goal for", "reading goal", "fitness goal", "study goal", "education goal",
                            "wellbeing goal", "wellness goal", "lifestyle goal", "finance goal", "money goal",
                            "skills goal", "cooking goal", "running goal", "sport goal", "health goal", "sleep goal"]
        guard goalPatterns.contains(where: { lower.contains($0) }) else { return nil }

        // Try to match a template by name keywords
        let templates = GoalTemplateCatalog.all
        var matched: GoalTemplate?
        for template in templates {
            let nameWords = template.name.lowercased().split(separator: " ")
            let stopWords: Set<String> = ["more", "into", "find", "keep", "build", "start"]
            if nameWords.contains(where: { word in
                let w = String(word)
                return w.count > 3 && !stopWords.contains(w) && lower.contains(w)
            }) {
                matched = template
                break
            }
        }
        // Also match by category keyword
        if matched == nil {
            for cat in GoalCategory.allCases {
                if lower.contains(cat.rawValue.lowercased()) {
                    let audience: GoalAudience = isIndividual ? .individual : .child
                    matched = templates.first { $0.category == cat && $0.audience.contains(audience) }
                    break
                }
            }
        }

        guard let template = matched else {
            return (.setGoal, "I found a few goal options. Try being more specific, like \"Set a reading goal for Arya\" or use the Goals tab for the full catalog.", nil, .none)
        }

        let person = extractPerson(from: original)
        let assignee = person ?? currentUser

        let entries = template.suggestedTasks.map {
            GoalTaskEntry(name: $0.name, frequency: $0.frequency, occurrences: $0.occurrences, reward: $0.reward, hour: $0.hour, minute: $0.minute)
        }

        var details: [String] = []
        details.append("🎯 \(template.name)")
        details.append("📂 \(template.category.rawValue) • \(template.durationDays) days")
        details.append("👤 \(assignee)")
        details.append("─────")
        details.append("Tasks:")
        for task in entries {
            details.append("  \(task.name) (\(task.frequency.rawValue) × \(task.occurrences)) - \(task.reward) coins")
        }
        let totalTasks = entries.reduce(0) { $0 + $1.occurrences }
        let totalCoins = entries.reduce(0) { $0 + $1.reward * $1.occurrences }
        details.append("─────")
        details.append("Total: \(totalTasks) tasks, \(totalCoins) coins possible")

        var action = TaskAction(intent: .setGoal, summary: "Set Goal: \(template.name)", details: details)
        action.goalName = template.name
        action.goalTemplateId = template.id
        action.goalCategory = template.category.rawValue
        action.goalDurationDays = template.durationDays
        action.goalIsCustom = false
        action.goalAssignees = [assignee]
        action.goalTasks = entries
        return (.setGoal, "Here's a goal I can set up for \(assignee):", action, .none)
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
final class SpeechManager: NSObject, AVSpeechSynthesizerDelegate {
    var isListening = false
    var transcribedText = ""
    var isSpeaking = false
    private(set) var isAuthorized = false

    private var speechRecognizer = SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    private var silenceTimer: Timer?
    private static let silenceDelay: TimeInterval = 2.0

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }

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
                    // Reset silence timer on each new partial result
                    self.resetSilenceTimer()
                }
                if error != nil || (result?.isFinal ?? false) {
                    self.silenceTimer?.invalidate()
                    self.silenceTimer = nil
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

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        guard !transcribedText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        silenceTimer = Timer.scheduledTimer(withTimeInterval: Self.silenceDelay, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.stopListening()
            }
        }
    }

    func stopListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil
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
        let cleanText = Self.stripEmojis(from: text)
        guard !cleanText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback, mode: .default, options: .duckOthers)
        try? audioSession.setActive(true)
        isSpeaking = true
        let utterance = AVSpeechUtterance(string: cleanText)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    private static func stripEmojis(from text: String) -> String {
        text.unicodeScalars.filter { scalar in
            // Keep basic Latin, common punctuation, and extended characters — skip emoji ranges
            !(scalar.properties.isEmoji && scalar.properties.isEmojiPresentation)
            && scalar.value != 0xFE0F // variation selector
        }.map(String.init).joined()
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
    let allGoals: [Goal]
    let isIndividual: Bool
    var theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default")
    var isInline: Bool = false

    @Query(sort: \ShoppingItem.createdAt) private var allShoppingItems: [ShoppingItem]
    @Query(sort: \WishListItem.createdAt) private var allWishListItems: [WishListItem]
    @Query(sort: \FamilyProject.createdAt) private var allProjects: [FamilyProject]
    @Query(sort: \ProjectIdea.createdAt) private var allProjectIdeas: [ProjectIdea]

    @State private var messages: [AIChatMessage] = []
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var pendingContext: PendingContext = .none
    @FocusState private var isInputFocused: Bool
    @State private var speechManager = SpeechManager()
    @State private var isVoiceOutputEnabled = false
    @State private var isVoiceMode = false
    @State private var pendingSpeechText: String?
    @State private var isEndingVoiceMode = false
    @State private var pendingVoiceAction: (action: TaskAction, messageId: UUID)?

    private var memberNames: [String] {
        var names = [authManager.userName]
        names += allMembers.filter { $0.name != authManager.userName }.map { $0.name }
        return names
    }

    var body: some View {
        if isInline {
            aiContent
        } else {
            NavigationStack {
                aiContent
            }
        }
    }

    private var aiContent: some View {
        ZStack {
            LinearGradient(colors: theme.gradientColors, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            TiledLogoBackground()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                messageList
                inputBar
            }
        }
        .navigationTitle("AI Assistant")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
        .environment(\.colorScheme, theme.colorScheme)
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
                        .foregroundStyle(.primary.opacity(0.6))
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
                        .foregroundStyle(isVoiceOutputEnabled ? theme.accentColor : .primary.opacity(0.6))
                }
            }
            if !isInline {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.primary)
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
        .onDisappear {
            messages.removeAll()
            ChatMemory.clear()
        }
        .onChange(of: messages.count) { oldCount, newCount in
            if isVoiceOutputEnabled, let last = messages.last, last.role == .assistant {
                // Don't interrupt ongoing speech — only speak new responses
                if !speechManager.isSpeaking {
                    speechManager.speak(last.text)
                } else if newCount > oldCount + 1 {
                    // Multiple messages added (e.g. action result) — queue the latest
                    pendingSpeechText = last.text
                }
            }
        }
    }

    // MARK: - Prompt Suggestions

    private var suggestedPrompts: [String] {
        if isIndividual {
            return [
                "How am I doing this week?",
                "Add milk, eggs, and bread to shopping list",
                "Create a weekend project to organize my desk",
                "Set a fitness goal for me",
                "What's on my wish list?",
                "Delete all cancelled tasks"
            ]
        } else {
            return [
                "How is the family doing this week?",
                "Add school supplies to the shopping cart",
                "Start a family project for the backyard garden",
                "Set a reading goal for the kids",
                "Add an idea to our travel project",
                "What tasks do the kids have today?"
            ]
        }
    }

    private var promptSuggestionChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(suggestedPrompts, id: \.self) { prompt in
                Button {
                    inputText = prompt
                    sendMessage()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                        Text(prompt)
                            .font(.caption)
                            .multilineTextAlignment(.leading)
                    }
                    .foregroundStyle(.primary.opacity(0.85))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(theme.cardBackground, in: Capsule())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
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

                    if messages.count <= 1 && !isProcessing {
                        promptSuggestionChips
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
                        proxy.scrollTo(lastId, anchor: .top)
                    }
                }
            }
            .onChange(of: isProcessing) { _, processing in
                if processing {
                    withAnimation {
                        proxy.scrollTo("typing", anchor: .top)
                    }
                }
            }
        }
    }

    private var typingIndicator: some View {
        HStack(spacing: 4) {
            Text("Thinking...")
                .font(.caption)
                .foregroundStyle(.primary.opacity(0.5))
            ProgressView()
                .tint(.primary.opacity(0.5))
                .scaleEffect(0.7)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
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
                    .foregroundStyle(isUser ? .white : .primary)
                    .padding(12)
                    .background(
                        isUser ? theme.accentColor : theme.cardBackground,
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
                    .foregroundStyle(.primary)
            }

            ForEach(action.details, id: \.self) { detail in
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.8))
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
                    .background(theme.accentColor, in: Capsule())
                }

                Button {
                    cancelAction(messageId: messageId)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                        Text("Cancel")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.primary.opacity(0.15), in: Capsule())
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(colorForIntent(action.intent).opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            if isVoiceMode {
                // Voice mode: listening area + keyboard toggle
                HStack(spacing: 12) {
                    Button {
                        exitVoiceMode()
                    } label: {
                        Image(systemName: "keyboard")
                            .font(.system(size: 18))
                            .foregroundStyle(.primary.opacity(0.6))
                    }

                    if speechManager.isListening {
                        HStack(spacing: 8) {
                            // Pulsing dot to indicate active listening
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                                .opacity(speechManager.isListening ? 1 : 0.3)
                                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: speechManager.isListening)
                            Text(inputText.isEmpty ? "Listening..." : inputText)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 20))
                    } else if isProcessing {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Thinking...")
                                .font(.subheadline)
                                .foregroundStyle(.primary.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 20))
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(theme.accentColor)
                            Text("Speak now...")
                                .font(.subheadline)
                                .foregroundStyle(.primary.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 20))
                    }
                }
            } else {
                // Text mode
                TextField("Ask me anything...", text: $inputText)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .padding(12)
                    .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
                    )
                    .focused($isInputFocused)
                    .onSubmit { sendMessage() }

                Button {
                    isVoiceMode = true
                    isVoiceOutputEnabled = true
                    speechManager.transcribedText = ""
                    inputText = ""
                    speechManager.startListening()
                } label: {
                    Image(systemName: "mic")
                        .font(.system(size: 22))
                        .foregroundStyle(.primary.opacity(0.6))
                }

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? .primary.opacity(0.3) : theme.accentColor)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isProcessing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.cardBackgroundLight)
        .onChange(of: speechManager.transcribedText) { _, newText in
            if speechManager.isListening && !newText.isEmpty {
                inputText = newText
            }
        }
        .onChange(of: speechManager.isListening) { _, listening in
            // Auto-send when speech recognition finishes (user paused) in voice mode
            if !listening && isVoiceMode && !inputText.trimmingCharacters(in: .whitespaces).isEmpty {
                sendMessage()
            }
        }
        .onChange(of: isProcessing) { _, processing in
            // Re-start listening after AI responds in voice mode (only if not speaking)
            if !processing && isVoiceMode && !isEndingVoiceMode && !speechManager.isListening && !speechManager.isSpeaking {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if isVoiceMode && !isEndingVoiceMode && !isProcessing && !speechManager.isSpeaking {
                        speechManager.transcribedText = ""
                        inputText = ""
                        speechManager.startListening()
                    }
                }
            }
        }
        .onChange(of: speechManager.isSpeaking) { _, speaking in
            if !speaking {
                // Speak any queued text first
                if let pending = pendingSpeechText {
                    pendingSpeechText = nil
                    speechManager.speak(pending)
                    return
                }
                // Re-start listening after voice output finishes in voice mode
                if isVoiceMode && !isEndingVoiceMode && !isProcessing && !speechManager.isListening {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if isVoiceMode && !isEndingVoiceMode && !isProcessing && !speechManager.isSpeaking {
                            speechManager.transcribedText = ""
                            inputText = ""
                            speechManager.startListening()
                        }
                    }
                }
            }
        }
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

    private func exitVoiceMode() {
        isVoiceMode = false
        isVoiceOutputEnabled = false
        isEndingVoiceMode = false
        pendingVoiceAction = nil
        speechManager.stopListening()
        speechManager.stopSpeaking()
    }

    private func sendMessage() {
        if speechManager.isListening {
            speechManager.stopListening()
        }
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        // Handle oral confirmation/decline for pending voice actions
        if let pending = pendingVoiceAction {
            let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if Self.isConfirmation(lower) {
                pendingVoiceAction = nil
                messages.append(AIChatMessage(role: .user, text: text))
                inputText = ""
                executeAction(pending.action, messageId: pending.messageId)
                saveChat()
                return
            } else if Self.isDecline(lower) {
                pendingVoiceAction = nil
                messages.append(AIChatMessage(role: .user, text: text))
                inputText = ""
                cancelAction(messageId: pending.messageId)
                messages.append(AIChatMessage(role: .assistant, text: "No problem, cancelled."))
                saveChat()
                return
            }
            // Not a confirmation/decline — treat as a new request and clear pending
            pendingVoiceAction = nil
        }

        let isFarewell = Self.isFarewellMessage(text)
        if isFarewell && isVoiceMode {
            isEndingVoiceMode = true
        }

        messages.append(AIChatMessage(role: .user, text: text))
        inputText = ""
        isProcessing = true
        saveChat()

        Task {
            await sendViaClaude(text)
            if isFarewell && isVoiceMode {
                // Wait for voice output to finish, then exit voice mode
                while speechManager.isSpeaking {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
                await MainActor.run {
                    exitVoiceMode()
                }
            }
        }
    }

    private static func isFarewellMessage(_ text: String) -> Bool {
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let farewellPhrases = [
            "bye", "goodbye", "good bye", "see you", "see ya",
            "i'm done", "im done", "i am done",
            "i'm good", "im good", "i am good",
            "thanks", "thank you", "that's all", "thats all",
            "that's it", "thats it", "nothing else",
            "all done", "we're done", "were done",
            "talk later", "catch you later", "later",
            "good night", "goodnight", "gotta go", "got to go"
        ]
        return farewellPhrases.contains(where: { lower.hasPrefix($0) || lower == $0 })
    }

    private static func isConfirmation(_ text: String) -> Bool {
        let confirmPhrases = [
            "yes", "yeah", "yep", "yup", "sure", "ok", "okay",
            "confirm", "do it", "go ahead", "go for it",
            "yes please", "yeah sure", "sounds good", "perfect",
            "please do", "yes do it", "that's right", "correct",
            "absolutely", "definitely", "proceed"
        ]
        return confirmPhrases.contains(where: { text.hasPrefix($0) || text == $0 })
    }

    private static func isDecline(_ text: String) -> Bool {
        let declinePhrases = [
            "no", "nope", "nah", "cancel", "don't", "dont",
            "never mind", "nevermind", "skip", "stop",
            "no thanks", "not now", "forget it", "scratch that"
        ]
        return declinePhrases.contains(where: { text.hasPrefix($0) || text == $0 })
    }

    private func selectModel(for message: String) -> String {
        let lower = message.lowercased()
        let actionKeywords = ["create", "add", "schedule", "reschedule", "cancel", "delete", "remove",
                              "assign", "update", "change", "move", "set", "mark", "complete", "done",
                              "pick up", "unassign", "recurring", "goal", "pause", "resume",
                              "cart", "shopping", "buy", "bought", "wish", "project", "idea", "status",
                              "remind", "reminder", "nudge", "notify"]
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
        let insightsSummary = InsightsEngine.compute(tasks: allTasks, goals: allGoals, members: allMembers, currentUser: authManager.userName, isIndividual: isIndividual)
        let goalCatalogSummary = GoalTemplateCatalog.summaryForPrompt()

        // Extended context for full capabilities
        var extendedContext = ""
        let goalsSummary = buildGoalsSummary()
        if goalsSummary != "No goals." { extendedContext += "\n\nCURRENT GOALS:\n\(goalsSummary)" }
        let shoppingSummary = buildShoppingSummary()
        if shoppingSummary != "Shopping list is empty." { extendedContext += "\n\nSHOPPING LIST:\n\(shoppingSummary)" }
        let wishSummary = buildWishListSummary()
        if wishSummary != "No wish list items." { extendedContext += "\n\nWISH LIST:\n\(wishSummary)" }
        let projectsSummary = buildProjectsSummary()
        if projectsSummary != "No projects." { extendedContext += "\n\nFAMILY PROJECTS:\n\(projectsSummary)" }

        do {
            let response = try await service.chat(
                userMessage: text,
                conversationHistory: Array(history),
                familyMembers: memberNames,
                currentUser: authManager.userName,
                isIndividual: isIndividual,
                tasksSummary: tasksSummary + extendedContext,
                insightsSummary: insightsSummary,
                goalCatalogSummary: goalCatalogSummary,
                model: model,
                isVoiceMode: isVoiceMode
            )

            subscriptionManager.recordAIMessage()

            if let parsedAction = response.action {
                let action = buildActionFromClaude(parsedAction)
                let msg = AIChatMessage(role: .assistant, text: response.message, action: action)
                messages.append(msg)

                // In voice mode, store pending action for oral confirmation
                if isVoiceMode, let action = action, !action.isExecuted, !action.isCancelled {
                    pendingVoiceAction = (action: action, messageId: msg.id)
                }
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

        let relevantTasks = allTasks.filter { !$0.isArchived }
            .sorted { $0.targetDate < $1.targetDate }

        if relevantTasks.isEmpty { return "No tasks scheduled." }

        // Split into today, upcoming, and past for clarity
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: today)!
        let todayTasks = relevantTasks.filter { $0.targetDate >= today && $0.targetDate < todayEnd }
        let upcomingTasks = relevantTasks.filter { $0.targetDate >= todayEnd }
        let pastTasks = relevantTasks.filter { $0.targetDate < today }

        func formatTask(_ task: Item) -> String {
            let status = task.isApproved ? "done" : task.isInReview ? "in-review" : task.isMissed ? "missed" : task.isCancelled ? "cancelled" : "open"
            let date = task.targetDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
            let who = task.assignedTo.isEmpty ? "" : " [\(task.assignedTo)]"
            let reward = task.reward > 0 ? " \(Int(task.reward))coins" : ""
            let recurring = task.isRecurring ? " [recurring]" : ""
            return "- \(task.name)\(who) | \(date) | \(status)\(reward)\(recurring)"
        }

        var lines: [String] = []

        if !todayTasks.isEmpty {
            lines.append("TODAY:")
            for task in todayTasks { lines.append(formatTask(task)) }
        }
        if !upcomingTasks.isEmpty {
            lines.append("UPCOMING:")
            for task in upcomingTasks.prefix(30) { lines.append(formatTask(task)) }
            if upcomingTasks.count > 30 { lines.append("...and \(upcomingTasks.count - 30) more upcoming") }
        }
        if !pastTasks.isEmpty {
            lines.append("RECENT PAST:")
            for task in pastTasks.suffix(20) { lines.append(formatTask(task)) }
            if pastTasks.count > 20 { lines.append("...and \(pastTasks.count - 20) more past tasks") }
        }
        return lines.joined(separator: "\n")
    }

    private func buildGoalsSummary() -> String {
        let myGoals = allGoals.filter { goal in
            isIndividual ? true : true // show all goals for context
        }
        if myGoals.isEmpty { return "No goals." }
        var lines: [String] = []
        for goal in myGoals.prefix(20) {
            let progress = goal.progress(from: allTasks)
            lines.append("- \(goal.name) [\(goal.assignedTo)] | \(goal.status) | \(Int(progress * 100))% done | \(goal.category)")
        }
        return lines.joined(separator: "\n")
    }

    private func buildShoppingSummary() -> String {
        if allShoppingItems.isEmpty { return "Shopping list is empty." }
        var lines: [String] = []
        for item in allShoppingItems {
            let status = item.isBought ? "bought" : "needed"
            lines.append("- \(item.name) [\(status)] (added by \(item.addedBy))")
        }
        return lines.joined(separator: "\n")
    }

    private func buildWishListSummary() -> String {
        if allWishListItems.isEmpty { return "No wish list items." }
        var lines: [String] = []
        for item in allWishListItems {
            lines.append("- \(item.name) (by \(item.ownerName))")
        }
        return lines.joined(separator: "\n")
    }

    private func buildProjectsSummary() -> String {
        if allProjects.isEmpty { return "No projects." }
        var lines: [String] = []
        for project in allProjects {
            let ideas = allProjectIdeas.filter { $0.projectId == project.id.uuidString }
            let tasks = allTasks.filter { $0.projectId == project.id.uuidString }
            lines.append("- \(project.name) [\(project.status)] | \(project.category) | \(ideas.count) ideas, \(tasks.count) tasks | by \(project.createdBy)")
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
            func buildParsedTask(name: String, assignee: String, date: Date, reward: Int, recurrenceStr: String, occurrences: Int?) -> (ParsedTask, [String]) {
                let recurrenceType: RecurrenceType = switch recurrenceStr {
                    case "daily": .daily
                    case "weekly": .weekly
                    case "monthly": .monthly
                    default: .none
                }
                let defaultOcc: Int = switch recurrenceType {
                    case .daily: 7
                    case .weekly: 4
                    case .monthly: 3
                    case .none: 1
                }
                let occ = occurrences ?? defaultOcc
                var pt = ParsedTask()
                pt.name = name
                pt.targetDate = date
                pt.assignedTo = assignee
                pt.reward = reward
                pt.recurrence = recurrenceType
                pt.occurrences = occ

                var details = [name]
                details.append("📅 \(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().hour().minute()))")
                details.append("👤 \(assignee)")
                if reward > 0 { details.append("⭐ \(reward) coins") }
                if recurrenceType != .none {
                    details.append("🔄 \(recurrenceType.rawValue) × \(occ) instances")
                }
                return (pt, details)
            }

            if let tasksArray = parsed.tasks, !tasksArray.isEmpty {
                var allParsed: [ParsedTask] = []
                var allDetails: [String] = []
                for taskDict in tasksArray {
                    guard let tName = taskDict["taskName"] as? String, !tName.isEmpty else { continue }
                    let tAssignee = taskDict["assignee"] as? String ?? authManager.userName
                    let tDate = parseDate(taskDict["date"] as? String) ?? Date()
                    let tReward = taskDict["reward"] as? Int ?? 0
                    let tRecurrence = (taskDict["recurrence"] as? String ?? "none").lowercased()
                    let tOccurrences = taskDict["occurrences"] as? Int
                    let (pt, details) = buildParsedTask(name: tName, assignee: tAssignee, date: tDate, reward: tReward, recurrenceStr: tRecurrence, occurrences: tOccurrences)
                    allParsed.append(pt)
                    if !allDetails.isEmpty { allDetails.append("─────") }
                    allDetails.append(contentsOf: details)
                }
                guard !allParsed.isEmpty else { return nil }
                let summary = allParsed.count == 1 ? "Create new task" : "Create \(allParsed.count) tasks"
                var action = TaskAction(intent: .create, summary: summary, details: allDetails)
                action.parsedTasks = allParsed
                action.parsedTask = allParsed.first
                return action
            }

            guard let name = parsed.taskName, !name.isEmpty else { return nil }
            let assignee = parsed.assignee ?? authManager.userName
            let date = parseDate(parsed.date) ?? Date()
            let reward = parsed.reward ?? 0
            let recurrenceStr = (parsed.recurrence ?? "none").lowercased()
            let (parsedTask, details) = buildParsedTask(name: name, assignee: assignee, date: date, reward: reward, recurrenceStr: recurrenceStr, occurrences: parsed.occurrences)

            let summary = parsedTask.recurrence != .none ? "Create recurring task (\(parsedTask.occurrences)×)" : "Create new task"
            var action = TaskAction(intent: .create, summary: summary, details: details)
            action.parsedTask = parsedTask
            action.parsedTasks = [parsedTask]
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
                !task.isArchived && matchNames.contains(where: { task.name.localizedCaseInsensitiveContains($0) })
            }

            if cancelScope == "series" {
                let seriesNames = Set(matching.map { $0.name })
                let seriesAssignees = Set(matching.map { $0.assignedTo })
                let seriesTasks = allTasks.filter { task in
                    !task.isArchived && task.isRecurring &&
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

        case "update":
            let matchNames = parsed.matchingTaskNames ?? [parsed.taskName].compactMap { $0 }
            guard !matchNames.isEmpty else { return nil }

            let scope = parsed.rescheduleScope ?? "instance"

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

            var details: [String] = []
            for task in matching {
                var changes: [String] = []
                if let newName = parsed.newName { changes.append("name → \(newName)") }
                if let newReward = parsed.newReward { changes.append("coins → \(newReward)") }
                if let newAssignee = parsed.newAssignee { changes.append("assign → \(newAssignee)") }
                details.append("\(task.emoji) \(task.name): \(changes.joined(separator: ", "))")
            }

            let scopeLabel = scope == "series" ? " (entire series)" : ""
            var action = TaskAction(intent: .update, summary: "Update \(matching.count) task\(matching.count == 1 ? "" : "s")\(scopeLabel)", details: details, tasks: matching)
            action.newName = parsed.newName
            action.newReward = parsed.newReward
            action.newAssignee = parsed.newAssignee
            action.rescheduleScope = scope
            return action

        case "setGoal":
            guard let goalName = parsed.goalName, !goalName.isEmpty else { return nil }

            let templateId = parsed.goalTemplateId ?? ""
            let assignees: [String]
            if let multiAssignees = parsed.assignees, !multiAssignees.isEmpty {
                assignees = multiAssignees
            } else if let single = parsed.assignee, !single.isEmpty {
                assignees = [single]
            } else {
                assignees = [authManager.userName]
            }
            let category = parsed.category ?? "Lifestyle"
            let durationDays = parsed.durationDays ?? 30
            let isCustom = parsed.isCustomGoal ?? templateId.isEmpty

            // Build goal task entries from AI response or fall back to template
            var goalTaskEntries: [GoalTaskEntry] = []
            if let tasksArray = parsed.goalTasks, !tasksArray.isEmpty {
                for taskDict in tasksArray {
                    guard let name = taskDict["taskName"] as? String, !name.isEmpty else { continue }
                    let freqStr = (taskDict["frequency"] as? String ?? "daily").lowercased()
                    let freq: RecurrenceType = switch freqStr {
                        case "daily": .daily
                        case "weekly": .weekly
                        case "monthly": .monthly
                        default: .daily
                    }
                    let occ = taskDict["occurrences"] as? Int ?? (freq == .daily ? 30 : freq == .weekly ? 4 : 3)
                    let reward = taskDict["reward"] as? Int ?? 2
                    let hour = taskDict["hour"] as? Int ?? 9
                    let minute = taskDict["minute"] as? Int ?? 0
                    goalTaskEntries.append(GoalTaskEntry(name: name, frequency: freq, occurrences: occ, reward: reward, hour: hour, minute: minute))
                }
            }

            // Fall back to template defaults if no tasks provided
            if goalTaskEntries.isEmpty, let template = GoalTemplateCatalog.all.first(where: { $0.id == templateId }) {
                goalTaskEntries = template.suggestedTasks.map {
                    GoalTaskEntry(name: $0.name, frequency: $0.frequency, occurrences: $0.occurrences, reward: $0.reward, hour: $0.hour, minute: $0.minute)
                }
            }

            guard !goalTaskEntries.isEmpty else { return nil }

            // Build preview details
            var details: [String] = []
            details.append("🎯 \(goalName)")
            details.append("📂 \(category) • \(durationDays) days")
            details.append("👤 \(assignees.joined(separator: ", "))")
            details.append("─────")
            details.append("Tasks:")
            for task in goalTaskEntries {
                let freqLabel = "\(task.frequency.rawValue) × \(task.occurrences)"
                details.append("  \(task.name) (\(freqLabel)) - \(task.reward) coins")
            }
            let totalTasks = goalTaskEntries.reduce(0) { $0 + $1.occurrences } * assignees.count
            let totalCoins = goalTaskEntries.reduce(0) { $0 + $1.reward * $1.occurrences } * assignees.count
            details.append("─────")
            details.append("Total: \(totalTasks) tasks, \(totalCoins) coins possible")

            var action = TaskAction(intent: .setGoal, summary: "Set Goal: \(goalName)", details: details)
            action.goalName = goalName
            action.goalTemplateId = templateId
            action.goalCategory = category
            action.goalDurationDays = durationDays
            action.goalIsCustom = isCustom
            action.goalAssignees = assignees
            action.goalTasks = goalTaskEntries
            return action

        case "deleteGoal", "pauseGoal", "resumeGoal", "completeGoal":
            guard let name = parsed.goalName, !name.isEmpty else { return nil }
            let matching = allGoals.filter { $0.name.localizedCaseInsensitiveContains(name) }
            guard !matching.isEmpty else { return nil }
            let intent: TaskIntent = switch parsed.intent {
            case "deleteGoal": .deleteGoal
            case "pauseGoal": .pauseGoal
            case "resumeGoal": .resumeGoal
            default: .completeGoal
            }
            let verb = switch intent {
            case .deleteGoal: "Delete"
            case .pauseGoal: "Pause"
            case .resumeGoal: "Resume"
            default: "Complete"
            }
            let details = matching.map { "🎯 \($0.name) [\($0.assignedTo)] — \($0.status)" }
            var action = TaskAction(intent: intent, summary: "\(verb) \(matching.count) goal\(matching.count == 1 ? "" : "s")", details: details)
            action.matchingGoals = matching
            action.goalName = name
            return action

        case "addToCart":
            let names = parsed.itemNames ?? [parsed.taskName].compactMap { $0 }
            guard !names.isEmpty else { return nil }
            let details = names.map { "🛒 \($0)" }
            var action = TaskAction(intent: .addToCart, summary: "Add \(names.count) item\(names.count == 1 ? "" : "s") to cart", details: details)
            action.itemNames = names
            return action

        case "removeFromCart":
            let names = parsed.itemNames ?? [parsed.taskName].compactMap { $0 }
            guard !names.isEmpty else { return nil }
            let matching = allShoppingItems.filter { item in
                names.contains(where: { item.name.localizedCaseInsensitiveContains($0) })
            }
            guard !matching.isEmpty else { return nil }
            let details = matching.map { "🛒 \($0.name)" }
            var action = TaskAction(intent: .removeFromCart, summary: "Remove \(matching.count) item\(matching.count == 1 ? "" : "s") from cart", details: details)
            action.matchingShoppingItems = matching
            return action

        case "markBought":
            let names = parsed.itemNames ?? [parsed.taskName].compactMap { $0 }
            guard !names.isEmpty else { return nil }
            let matching = allShoppingItems.filter { item in
                names.contains(where: { item.name.localizedCaseInsensitiveContains($0) })
            }
            guard !matching.isEmpty else { return nil }
            let details = matching.map { "\($0.isBought ? "↩️" : "✅") \($0.name) → \($0.isBought ? "needed" : "bought")" }
            var action = TaskAction(intent: .markBought, summary: "Toggle \(matching.count) item\(matching.count == 1 ? "" : "s")", details: details)
            action.matchingShoppingItems = matching
            return action

        case "addToWishList":
            let names = parsed.itemNames ?? [parsed.taskName].compactMap { $0 }
            guard !names.isEmpty else { return nil }
            let details = names.map { "⭐ \($0)" }
            var action = TaskAction(intent: .addToWishList, summary: "Add \(names.count) item\(names.count == 1 ? "" : "s") to wish list", details: details)
            action.itemNames = names
            return action

        case "removeFromWishList":
            let names = parsed.itemNames ?? [parsed.taskName].compactMap { $0 }
            guard !names.isEmpty else { return nil }
            let matching = allWishListItems.filter { item in
                names.contains(where: { item.name.localizedCaseInsensitiveContains($0) })
            }
            guard !matching.isEmpty else { return nil }
            let details = matching.map { "⭐ \($0.name)" }
            var action = TaskAction(intent: .removeFromWishList, summary: "Remove \(matching.count) item\(matching.count == 1 ? "" : "s") from wish list", details: details)
            action.matchingWishListItems = matching
            return action

        case "createProject":
            guard let name = parsed.projectName, !name.isEmpty else { return nil }
            var details = ["📁 \(name)"]
            if let desc = parsed.projectDescription, !desc.isEmpty { details.append("📝 \(desc)") }
            if let cat = parsed.projectCategory { details.append("📂 \(cat)") }
            var action = TaskAction(intent: .createProject, summary: "Create project: \(name)", details: details)
            action.projectName = name
            action.projectDescription = parsed.projectDescription
            action.projectCategory = parsed.projectCategory
            return action

        case "editProject":
            guard let name = parsed.projectName, !name.isEmpty else { return nil }
            let matching = allProjects.filter { $0.name.localizedCaseInsensitiveContains(name) }
            guard !matching.isEmpty else { return nil }
            var changes: [String] = []
            if let n = parsed.newName { changes.append("name → \(n)") }
            if let d = parsed.projectDescription { changes.append("description → \(d)") }
            if let c = parsed.projectCategory { changes.append("category → \(c)") }
            let details = matching.map { "📁 \($0.name): \(changes.joined(separator: ", "))" }
            var action = TaskAction(intent: .editProject, summary: "Edit \(matching.count) project\(matching.count == 1 ? "" : "s")", details: details)
            action.matchingProjects = matching
            action.newName = parsed.newName
            action.projectDescription = parsed.projectDescription
            action.projectCategory = parsed.projectCategory
            return action

        case "deleteProject":
            guard let name = parsed.projectName, !name.isEmpty else { return nil }
            let matching = allProjects.filter { $0.name.localizedCaseInsensitiveContains(name) }
            guard !matching.isEmpty else { return nil }
            let details = matching.map { "📁 \($0.name) [\($0.status)]" }
            var action = TaskAction(intent: .deleteProject, summary: "Delete \(matching.count) project\(matching.count == 1 ? "" : "s")", details: details)
            action.matchingProjects = matching
            return action

        case "updateProjectStatus":
            guard let name = parsed.projectName, !name.isEmpty,
                  let status = parsed.projectStatus, !status.isEmpty else { return nil }
            let matching = allProjects.filter { $0.name.localizedCaseInsensitiveContains(name) }
            guard !matching.isEmpty else { return nil }
            let details = matching.map { "📁 \($0.name): \($0.status) → \(status)" }
            var action = TaskAction(intent: .updateProjectStatus, summary: "Update project status", details: details)
            action.matchingProjects = matching
            action.projectStatus = status
            return action

        case "addProjectIdea":
            guard let name = parsed.projectName, !name.isEmpty,
                  let idea = parsed.ideaText, !idea.isEmpty else { return nil }
            let matching = allProjects.filter { $0.name.localizedCaseInsensitiveContains(name) }
            guard !matching.isEmpty else { return nil }
            let details = ["📁 \(matching.first!.name)", "💡 \(idea)"]
            var action = TaskAction(intent: .addProjectIdea, summary: "Add idea to \(matching.first!.name)", details: details)
            action.matchingProjects = matching
            action.ideaText = idea
            return action

        case "sendReminder":
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
            let scope = parsed.reminderScope ?? ""
            let assignee = parsed.assignee

            var matching: [Item]
            if scope == "today" {
                // All open tasks for today, optionally filtered by assignee
                matching = allTasks.filter { task in
                    task.isOpen && !task.isArchived &&
                    task.targetDate >= today && task.targetDate < tomorrow &&
                    (assignee == nil || task.assignedTo.localizedCaseInsensitiveContains(assignee!))
                }
            } else {
                // Match specific tasks by name
                let matchNames = parsed.matchingTaskNames ?? [parsed.taskName].compactMap { $0 }
                guard !matchNames.isEmpty else { return nil }
                matching = allTasks.filter { task in
                    task.isOpen && !task.isArchived &&
                    matchNames.contains(where: { task.name.localizedCaseInsensitiveContains($0) }) &&
                    (assignee == nil || task.assignedTo.localizedCaseInsensitiveContains(assignee!))
                }
            }
            guard !matching.isEmpty else { return nil }

            let memberSet = Set(matching.map { $0.assignedTo }).filter { !$0.isEmpty }
            let memberLabel = memberSet.isEmpty ? "" : " to \(memberSet.joined(separator: ", "))"
            let details = matching.map { "🔔 \($0.name) [\($0.assignedTo.isEmpty ? "unassigned" : $0.assignedTo)]" }
            var action = TaskAction(intent: .sendReminder, summary: "Send \(matching.count) reminder\(matching.count == 1 ? "" : "s")\(memberLabel)", details: details, tasks: matching)
            action.reminderScope = scope
            return action

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
        case .update:
            executeUpdate(action, messageId: messageId)
        case .setGoal:
            executeSetGoal(action, messageId: messageId)
        case .deleteGoal, .pauseGoal, .resumeGoal, .completeGoal:
            executeGoalAction(action, messageId: messageId)
        case .addToCart:
            executeAddToCart(action, messageId: messageId)
        case .removeFromCart:
            executeRemoveFromCart(action, messageId: messageId)
        case .markBought:
            executeMarkBought(action, messageId: messageId)
        case .addToWishList:
            executeAddToWishList(action, messageId: messageId)
        case .removeFromWishList:
            executeRemoveFromWishList(action, messageId: messageId)
        case .createProject:
            executeCreateProject(action, messageId: messageId)
        case .editProject:
            executeEditProject(action, messageId: messageId)
        case .deleteProject:
            executeDeleteProject(action, messageId: messageId)
        case .updateProjectStatus:
            executeUpdateProjectStatus(action, messageId: messageId)
        case .addProjectIdea:
            executeAddProjectIdea(action, messageId: messageId)
        case .sendReminder:
            executeSendReminder(action, messageId: messageId)
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

    private func executeUpdate(_ action: TaskAction, messageId: UUID) {
        var updated = 0
        var skipped = 0
        var changes: [String] = []

        for task in action.tasks {
            guard task.isOpen else {
                skipped += 1
                continue
            }

            if let newName = action.newName {
                task.name = newName
            }
            if let newReward = action.newReward {
                task.reward = Double(newReward)
            }
            if let newAssignee = action.newAssignee {
                task.assignedTo = newAssignee
            }
            updated += 1
        }

        try? modelContext.save()

        let familyCode = authManager.familyCode
        let snapshots = action.tasks.filter { $0.isOpen }.map { CloudKitManager.TaskSnapshot($0) }
        Task {
            for snap in snapshots {
                await cloudKitManager.pushTaskSnapshot(snap, familyCode: familyCode)
            }
        }

        markActionExecuted(messageId: messageId)

        if let n = action.newName { changes.append("renamed to \"\(n)\"") }
        if let r = action.newReward { changes.append("coins set to \(r)") }
        if let a = action.newAssignee { changes.append("assigned to \(a)") }
        let scopeNote = action.rescheduleScope == "series" ? " (entire series)" : ""
        var response = "✅ Done! \(updated) task\(updated == 1 ? "" : "s") updated\(scopeNote): \(changes.joined(separator: ", "))."
        if skipped > 0 {
            response += " \(skipped) task\(skipped == 1 ? " was" : "s were") skipped (no longer open)."
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
            var taskIDs: [UUID] = []
            for task in action.tasks {
                if task.isOpen {
                    task.status = "cancelled"
                    notificationManager.cancelTaskReminder(taskId: task.id)
                    cancelled += 1
                } else {
                    // Already cancelled/missed/done — delete outright
                    notificationManager.cancelTaskReminder(taskId: task.id)
                    taskIDs.append(task.id)
                    withAnimation { modelContext.delete(task) }
                    deleted += 1
                }
            }
            try? modelContext.save()
            let familyCode = authManager.familyCode
            let snapshots = action.tasks.filter { !taskIDs.contains($0.id) }.map { CloudKitManager.TaskSnapshot($0) }
            Task {
                for snap in snapshots {
                    await cloudKitManager.pushTaskSnapshot(snap, familyCode: familyCode)
                }
                await cloudKitManager.deleteRemoteTasks(taskIDs)
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
            var parts: [String] = []
            if cancelled > 0 { parts.append("\(cancelled) task\(cancelled == 1 ? "" : "s") cancelled") }
            if deleted > 0 { parts.append("\(deleted) task\(deleted == 1 ? "" : "s") deleted") }
            messages.append(AIChatMessage(role: .assistant, text: "✅ \(parts.joined(separator: ", "))."))
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
        let taskList = action.parsedTasks.isEmpty ? [action.parsedTask].compactMap { $0 } : action.parsedTasks
        guard !taskList.isEmpty else {
            messages.append(AIChatMessage(role: .assistant, text: "Something went wrong — task details were missing. Please try creating the task again."))
            return
        }

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

        var allCreated: [Item] = []
        var summaryParts: [String] = []

        for parsed in taskList {
            let assignee = parsed.assignedTo.isEmpty ? (action.newAssignee ?? authManager.userName) : parsed.assignedTo
            let isRecurring = parsed.recurrence != .none
            let dates = generateRecurringDates(startDate: parsed.targetDate, recurrence: parsed.recurrence, occurrences: parsed.occurrences)

            var createdForThis: [Item] = []
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
                createdForThis.append(task)
                subscriptionManager.recordTaskCreation()
                notificationManager.scheduleTaskReminder(taskId: task.id, taskName: task.name, assignedTo: assignee, dueDate: date)
            }
            allCreated.append(contentsOf: createdForThis)

            if isRecurring {
                let lastDate = dates.last ?? parsed.targetDate
                var part = "✅ \(createdForThis.count)× \"\(parsed.name)\""
                part += " (\(parsed.recurrence.rawValue), \(parsed.targetDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())) → \(lastDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())))"
                part += " 👤 \(assignee)"
                if parsed.reward > 0 { part += " ⭐ \(parsed.reward) coins each" }
                summaryParts.append(part)
            } else {
                var part = "✅ \"\(parsed.name)\""
                part += " 📅 \(parsed.targetDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().hour().minute()))"
                part += " 👤 \(assignee)"
                if parsed.reward > 0 { part += " ⭐ \(parsed.reward) coins" }
                summaryParts.append(part)
            }
        }

        try? modelContext.save()

        let familyCode = authManager.familyCode
        Task {
            for task in allCreated {
                await cloudKitManager.pushTask(task, familyCode: familyCode)
            }
        }

        markActionExecuted(messageId: messageId)

        var response = summaryParts.joined(separator: "\n")
        response += "\n\n\(allCreated.count) task\(allCreated.count == 1 ? "" : "s") created with reminders set."
        messages.append(AIChatMessage(role: .assistant, text: response))
    }

    private func executeSetGoal(_ action: TaskAction, messageId: UUID) {
        guard let goalName = action.goalName, !action.goalTasks.isEmpty else {
            messages.append(AIChatMessage(role: .assistant, text: "Something went wrong — goal details were missing. Please try again."))
            return
        }

        if !subscriptionManager.canCreateMoreTasks(allTasks: allTasks) {
            markActionExecuted(messageId: messageId)
            messages.append(AIChatMessage(role: .assistant, text: "You've reached the task limit for this month. Upgrade your plan to create more tasks."))
            return
        }

        let assignees = action.goalAssignees.isEmpty ? [authManager.userName] : action.goalAssignees
        let category = action.goalCategory ?? "Lifestyle"
        let durationDays = action.goalDurationDays ?? 30
        let templateId = action.goalTemplateId ?? ""
        let isCustom = action.goalIsCustom
        let icon = GoalCategory(rawValue: category)?.icon ?? "target"

        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        let targetDate = calendar.date(byAdding: .day, value: durationDays, to: startDate) ?? startDate

        // Check for duplicate active goals
        let existingGoals: [Goal] = (try? modelContext.fetch(FetchDescriptor<Goal>())) ?? []

        var allCreatedItems: [Item] = []
        var goalSummaries: [String] = []

        for assignee in assignees {
            let hasDuplicate = existingGoals.contains { $0.assignedTo == assignee && $0.isActive && ($0.templateId == templateId || $0.name == goalName) }
            if hasDuplicate {
                goalSummaries.append("⚠️ \(assignee) already has an active \"\(goalName)\" goal — skipped.")
                continue
            }

            let goal = Goal(
                name: goalName,
                category: category,
                icon: icon,
                assignedTo: assignee,
                createdBy: authManager.userName,
                targetDate: targetDate,
                isCustom: isCustom,
                templateId: templateId
            )
            modelContext.insert(goal)

            var tasksCreated = 0
            for entry in action.goalTasks {
                let baseDate = calendar.date(bySettingHour: entry.hour, minute: entry.minute, second: 0, of: startDate) ?? startDate
                let isRecurring = entry.frequency != .none
                let dates = generateRecurringDates(startDate: baseDate, recurrence: entry.frequency, occurrences: entry.occurrences)

                for date in dates {
                    let item = Item(
                        name: entry.name,
                        targetDate: date,
                        assignedTo: assignee,
                        reward: Double(entry.reward),
                        isRecurring: isRecurring,
                        createdBy: authManager.userName,
                        createdByID: authManager.appleUserID
                    )
                    item.goalId = goal.id.uuidString
                    modelContext.insert(item)
                    allCreatedItems.append(item)
                    subscriptionManager.recordTaskCreation()
                    notificationManager.scheduleTaskReminder(taskId: item.id, taskName: item.name, assignedTo: assignee, dueDate: date)
                    tasksCreated += 1
                }
            }
            goalSummaries.append("🎯 \"\(goalName)\" for \(assignee) — \(tasksCreated) tasks created")
        }

        try? modelContext.save()

        let familyCode = authManager.familyCode
        Task {
            for item in allCreatedItems {
                await cloudKitManager.pushTask(item, familyCode: familyCode)
            }
        }

        markActionExecuted(messageId: messageId)

        var response = goalSummaries.joined(separator: "\n")
        response += "\n\n\(allCreatedItems.count) total task\(allCreatedItems.count == 1 ? "" : "s") scheduled with reminders set."
        messages.append(AIChatMessage(role: .assistant, text: response))
    }

    // MARK: - Goal Management Actions

    private func executeGoalAction(_ action: TaskAction, messageId: UUID) {
        guard !action.matchingGoals.isEmpty else {
            messages.append(AIChatMessage(role: .assistant, text: "Couldn't find that goal. Please try again."))
            return
        }

        var summaries: [String] = []

        for goal in action.matchingGoals {
            switch action.intent {
            case .deleteGoal:
                let openTasks = allTasks.filter { $0.goalId == goal.id.uuidString && $0.isOpen }
                for task in openTasks {
                    notificationManager.cancelTaskReminder(taskId: task.id)
                    modelContext.delete(task)
                }
                modelContext.delete(goal)
                summaries.append("🗑️ Deleted \"\(goal.name)\" and \(openTasks.count) open task\(openTasks.count == 1 ? "" : "s").")
            case .pauseGoal:
                goal.status = "paused"
                summaries.append("⏸️ Paused \"\(goal.name)\".")
            case .resumeGoal:
                goal.status = "active"
                summaries.append("▶️ Resumed \"\(goal.name)\".")
            case .completeGoal:
                goal.status = "completed"
                summaries.append("🎉 Completed \"\(goal.name)\"!")
            default:
                break
            }
        }

        try? modelContext.save()
        markActionExecuted(messageId: messageId)
        messages.append(AIChatMessage(role: .assistant, text: summaries.joined(separator: "\n")))
    }

    // MARK: - Shopping List Actions

    private func executeAddToCart(_ action: TaskAction, messageId: UUID) {
        var added = 0
        var createdItems: [ShoppingItem] = []
        for name in action.itemNames {
            let item = ShoppingItem(name: name, addedBy: authManager.userName)
            modelContext.insert(item)
            createdItems.append(item)
            added += 1
        }
        try? modelContext.save()

        let familyCode = authManager.familyCode
        Task {
            for item in createdItems {
                let snap = CloudKitManager.ShoppingSnapshot(item)
                await cloudKitManager.pushShoppingSnapshot(snap, familyCode: familyCode)
            }
        }

        markActionExecuted(messageId: messageId)
        messages.append(AIChatMessage(role: .assistant, text: "🛒 Added \(added) item\(added == 1 ? "" : "s") to the shopping list."))
    }

    private func executeRemoveFromCart(_ action: TaskAction, messageId: UUID) {
        var removed = 0
        let familyCode = authManager.familyCode
        var idsToDelete: [UUID] = []
        for item in action.matchingShoppingItems {
            idsToDelete.append(item.id)
            modelContext.delete(item)
            removed += 1
        }
        try? modelContext.save()

        Task {
            for id in idsToDelete {
                await cloudKitManager.deleteShoppingItem(id: id, familyCode: familyCode)
            }
        }

        markActionExecuted(messageId: messageId)
        messages.append(AIChatMessage(role: .assistant, text: "🗑️ Removed \(removed) item\(removed == 1 ? "" : "s") from the shopping list."))
    }

    private func executeMarkBought(_ action: TaskAction, messageId: UUID) {
        var toggled = 0
        for item in action.matchingShoppingItems {
            item.isBought.toggle()
            toggled += 1
        }
        try? modelContext.save()

        let familyCode = authManager.familyCode
        Task {
            for item in action.matchingShoppingItems {
                let snap = CloudKitManager.ShoppingSnapshot(item)
                await cloudKitManager.pushShoppingSnapshot(snap, familyCode: familyCode)
            }
        }

        markActionExecuted(messageId: messageId)
        messages.append(AIChatMessage(role: .assistant, text: "✅ Updated \(toggled) item\(toggled == 1 ? "" : "s") in the shopping list."))
    }

    // MARK: - Wish List Actions

    private func executeAddToWishList(_ action: TaskAction, messageId: UUID) {
        var added = 0
        var createdItems: [WishListItem] = []
        for name in action.itemNames {
            let item = WishListItem(name: name, ownerAppleUserID: authManager.appleUserID, ownerName: authManager.userName)
            modelContext.insert(item)
            createdItems.append(item)
            added += 1
        }
        try? modelContext.save()

        let familyCode = authManager.familyCode
        Task {
            for item in createdItems {
                await cloudKitManager.pushWishListItem(item, familyCode: familyCode)
            }
        }

        markActionExecuted(messageId: messageId)
        messages.append(AIChatMessage(role: .assistant, text: "⭐ Added \(added) item\(added == 1 ? "" : "s") to your wish list."))
    }

    private func executeRemoveFromWishList(_ action: TaskAction, messageId: UUID) {
        var removed = 0
        let familyCode = authManager.familyCode
        var idsToDelete: [UUID] = []
        for item in action.matchingWishListItems {
            idsToDelete.append(item.id)
            modelContext.delete(item)
            removed += 1
        }
        try? modelContext.save()

        Task {
            for id in idsToDelete {
                await cloudKitManager.deleteWishListItem(id: id, familyCode: familyCode)
            }
        }

        markActionExecuted(messageId: messageId)
        messages.append(AIChatMessage(role: .assistant, text: "🗑️ Removed \(removed) item\(removed == 1 ? "" : "s") from wish list."))
    }

    // MARK: - Project Actions

    private func executeCreateProject(_ action: TaskAction, messageId: UUID) {
        guard let name = action.projectName else {
            messages.append(AIChatMessage(role: .assistant, text: "Project name is missing. Please try again."))
            return
        }
        let project = FamilyProject(
            name: name,
            descriptionText: action.projectDescription ?? "",
            category: action.projectCategory ?? "Fun",
            createdBy: authManager.userName
        )
        modelContext.insert(project)
        try? modelContext.save()

        let familyCode = authManager.familyCode
        let projectCopy = project
        Task {
            await cloudKitManager.pushProject(projectCopy, familyCode: familyCode)
        }

        markActionExecuted(messageId: messageId)
        messages.append(AIChatMessage(role: .assistant, text: "📁 Created project \"\(name)\"."))
    }

    private func executeEditProject(_ action: TaskAction, messageId: UUID) {
        var updated = 0
        for project in action.matchingProjects {
            if let n = action.newName { project.name = n }
            if let d = action.projectDescription { project.descriptionText = d }
            if let c = action.projectCategory { project.category = c }
            updated += 1
        }
        try? modelContext.save()

        let familyCode = authManager.familyCode
        let projects = action.matchingProjects
        Task {
            for project in projects {
                await cloudKitManager.pushProject(project, familyCode: familyCode)
            }
        }

        markActionExecuted(messageId: messageId)
        messages.append(AIChatMessage(role: .assistant, text: "📁 Updated \(updated) project\(updated == 1 ? "" : "s")."))
    }

    private func executeDeleteProject(_ action: TaskAction, messageId: UUID) {
        var deleted = 0
        var deletedProjectIDs: [UUID] = []
        var deletedIdeaIDs: [UUID] = []
        for project in action.matchingProjects {
            // Delete associated ideas
            let ideas = allProjectIdeas.filter { $0.projectId == project.id.uuidString }
            for idea in ideas {
                deletedIdeaIDs.append(idea.id)
                modelContext.delete(idea)
            }
            // Unlink tasks (don't delete — just remove project association)
            let tasks = allTasks.filter { $0.projectId == project.id.uuidString }
            for task in tasks { task.projectId = "" }
            deletedProjectIDs.append(project.id)
            modelContext.delete(project)
            deleted += 1
        }
        try? modelContext.save()

        Task {
            for ideaID in deletedIdeaIDs {
                await cloudKitManager.deleteRemoteIdea(ideaID)
            }
            for projectID in deletedProjectIDs {
                await cloudKitManager.deleteRemoteProject(projectID)
            }
        }

        markActionExecuted(messageId: messageId)
        messages.append(AIChatMessage(role: .assistant, text: "🗑️ Deleted \(deleted) project\(deleted == 1 ? "" : "s")."))
    }

    private func executeUpdateProjectStatus(_ action: TaskAction, messageId: UUID) {
        guard let newStatus = action.projectStatus else {
            messages.append(AIChatMessage(role: .assistant, text: "No status specified. Please try again."))
            return
        }
        var updated = 0
        for project in action.matchingProjects {
            project.status = newStatus
            updated += 1
        }
        try? modelContext.save()

        let familyCode = authManager.familyCode
        let projects = action.matchingProjects
        Task {
            for project in projects {
                await cloudKitManager.pushProject(project, familyCode: familyCode)
            }
        }

        markActionExecuted(messageId: messageId)
        messages.append(AIChatMessage(role: .assistant, text: "📁 Updated \(updated) project\(updated == 1 ? "" : "s") to \"\(newStatus)\"."))
    }

    private func executeAddProjectIdea(_ action: TaskAction, messageId: UUID) {
        guard let project = action.matchingProjects.first,
              let ideaText = action.ideaText else {
            messages.append(AIChatMessage(role: .assistant, text: "Couldn't find the project or idea text. Please try again."))
            return
        }
        let idea = ProjectIdea(
            projectId: project.id.uuidString,
            text: ideaText,
            submittedBy: authManager.userName
        )
        modelContext.insert(idea)
        try? modelContext.save()

        let familyCode = authManager.familyCode
        let ideaCopy = idea
        Task {
            await cloudKitManager.pushIdea(ideaCopy, familyCode: familyCode)
        }

        markActionExecuted(messageId: messageId)
        messages.append(AIChatMessage(role: .assistant, text: "💡 Added idea to \"\(project.name)\": \(ideaText)"))
    }

    private func executeSendReminder(_ action: TaskAction, messageId: UUID) {
        guard !action.tasks.isEmpty else {
            messages.append(AIChatMessage(role: .assistant, text: "No matching tasks found to send reminders for."))
            return
        }

        var reminded = 0
        let now = Date()
        for task in action.tasks {
            task.lastRemindedAt = now
            reminded += 1
        }
        try? modelContext.save()

        // Push updated tasks to CloudKit — the receiver's device will show notification via sync
        let familyCode = authManager.familyCode
        let snapshots = action.tasks.map { CloudKitManager.TaskSnapshot($0) }
        Task {
            for snap in snapshots {
                await cloudKitManager.pushTaskSnapshot(snap, familyCode: familyCode)
            }
        }

        let memberSet = Set(action.tasks.compactMap { $0.assignedTo.isEmpty ? nil : $0.assignedTo })
        let memberLabel = memberSet.isEmpty ? "" : " to \(memberSet.joined(separator: ", "))"

        markActionExecuted(messageId: messageId)
        messages.append(AIChatMessage(role: .assistant, text: "🔔 Sent \(reminded) reminder\(reminded == 1 ? "" : "s")\(memberLabel)."))
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
        case .setGoal: return "target"
        case .deleteGoal: return "trash.circle.fill"
        case .pauseGoal: return "pause.circle.fill"
        case .resumeGoal: return "play.circle.fill"
        case .completeGoal: return "checkmark.seal.fill"
        case .addToCart: return "cart.badge.plus"
        case .removeFromCart: return "cart.badge.minus"
        case .markBought: return "bag.fill"
        case .addToWishList: return "star.circle.fill"
        case .removeFromWishList: return "star.slash.fill"
        case .createProject: return "folder.badge.plus"
        case .editProject: return "pencil.circle.fill"
        case .deleteProject: return "folder.badge.minus"
        case .updateProjectStatus: return "arrow.right.circle.fill"
        case .addProjectIdea: return "lightbulb.fill"
        case .sendReminder: return "bell.badge.fill"
        default: return "sparkles"
        }
    }

    private func colorForIntent(_ intent: TaskIntent) -> Color {
        switch intent {
        case .create: return theme.accentColor
        case .reschedule: return .orange
        case .cancel, .deleteGoal, .deleteProject, .removeFromCart, .removeFromWishList: return .red
        case .markDone, .completeGoal, .markBought: return .green
        case .setGoal, .resumeGoal: return theme.accentColor
        case .pauseGoal: return .orange
        case .addToCart, .addToWishList: return theme.accentColor
        case .createProject, .editProject, .updateProjectStatus, .addProjectIdea: return theme.accentColor
        case .sendReminder: return .orange
        default: return theme.accentColor
        }
    }
}
