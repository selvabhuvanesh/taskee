//
//  NotificationManager.swift
//  Taskee
//

import Foundation
import UserNotifications
import AVFoundation

@Observable
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    var showPendingApprovals = false
    var pickupAckChildName: String?
    var onPickupAcknowledged: ((String) -> Void)?
    private static let snoozeActionID = "SNOOZE_ACTION"
    private static let dismissActionID = "DISMISS_ACTION"
    private static let pickupAckActionID = "PICKUP_ACK_ACTION"
    private static let taskReminderCategoryID = "TASK_REMINDER"
    private static let snoozeDuration: TimeInterval = 5 * 60

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        registerCategories()
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .providesAppNotificationSettings]) { _, _ in }
    }

    private func registerCategories() {
        let snooze = UNNotificationAction(
            identifier: Self.snoozeActionID,
            title: "Snooze (5 min)",
            options: []
        )
        let dismiss = UNNotificationAction(
            identifier: Self.dismissActionID,
            title: "Dismiss",
            options: .destructive
        )

        let taskReminder = UNNotificationCategory(
            identifier: Self.taskReminderCategoryID,
            actions: [snooze, dismiss],
            intentIdentifiers: []
        )

        let taskReview = UNNotificationCategory(
            identifier: "TASK_REVIEW",
            actions: [],
            intentIdentifiers: []
        )

        let pickupAck = UNNotificationAction(
            identifier: Self.pickupAckActionID,
            title: "On My Way!",
            options: .foreground
        )

        let pickup = UNNotificationCategory(
            identifier: "PICKUP_REQUEST",
            actions: [pickupAck],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([taskReminder, taskReview, pickup])
    }

    // MARK: - Reminder Intervals

    static let allReminderIntervals: [(minutes: Int, label: String)] = [
        (30, "30 minutes before"),
        (15, "15 minutes before"),
        (5, "5 minutes before"),
        (0, "At task time"),
    ]

    private static let reminderIntervalsKey = "enabledReminderIntervals"

    var enabledReminderIntervals: [Int] {
        get {
            if let stored = UserDefaults.standard.array(forKey: Self.reminderIntervalsKey) as? [Int] {
                return stored
            }
            return [30, 15, 5, 0]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.reminderIntervalsKey)
        }
    }

    func isIntervalEnabled(_ minutes: Int) -> Bool {
        enabledReminderIntervals.contains(minutes)
    }

    func toggleInterval(_ minutes: Int) {
        var current = enabledReminderIntervals
        if let idx = current.firstIndex(of: minutes) {
            current.remove(at: idx)
        } else {
            current.append(minutes)
            current.sort(by: >)
        }
        enabledReminderIntervals = current
    }

    // MARK: - Voice Reminder

    private let voiceSynthesizer = AVSpeechSynthesizer()

    func speakReminder(_ text: String) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.overrideOutputAudioPort(.speaker)
            try session.setActive(true)
        } catch { }

        if voiceSynthesizer.isSpeaking {
            voiceSynthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.volume = 1.0
        voiceSynthesizer.speak(utterance)
    }

    private func timeLabel(forMinutes minutes: Int) -> String {
        switch minutes {
        case 0: return "now"
        case 1: return "in 1 minute"
        default: return "in \(minutes) minutes"
        }
    }

    private func bodyTimeLabel(forMinutes minutes: Int) -> String {
        switch minutes {
        case 0: return "is due now"
        case 1: return "is due in 1 minute"
        default: return "is due in \(minutes) minutes"
        }
    }

    func scheduleTaskReminder(taskId: UUID, taskName: String, assignedTo: String, dueDate: Date) {
        let intervals = enabledReminderIntervals
        guard !intervals.isEmpty else { return }

        let center = UNUserNotificationCenter.current()
        var allPossibleIDs = Self.allReminderIntervals.map { "reminder-\(taskId.uuidString)-\($0.minutes)" }
        allPossibleIDs.append("reminder-\(taskId.uuidString)")
        center.removePendingNotificationRequests(withIdentifiers: allPossibleIDs)

        for minutes in intervals {
            let reminderDate = dueDate.addingTimeInterval(-Double(minutes) * 60)
            guard reminderDate > Date() else { continue }

            let spokenText = assignedTo.isEmpty
                ? "\(taskName) \(timeLabel(forMinutes: minutes))"
                : "\(taskName) for \(assignedTo) \(timeLabel(forMinutes: minutes))"

            let content = UNMutableNotificationContent()
            content.title = minutes == 0 ? "Task Due Now" : "Task Due Soon"
            content.body = assignedTo.isEmpty
                ? "\"\(taskName)\" \(bodyTimeLabel(forMinutes: minutes))"
                : "\"\(taskName)\" assigned to \(assignedTo) \(bodyTimeLabel(forMinutes: minutes))"
            content.sound = UNNotificationSound(named: UNNotificationSoundName("reminder.wav"))
            content.categoryIdentifier = "TASK_REMINDER"
            content.interruptionLevel = .timeSensitive
            content.userInfo = ["spokenText": spokenText]

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: reminderDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(
                identifier: "reminder-\(taskId.uuidString)-\(minutes)",
                content: content,
                trigger: trigger
            )

            center.add(request)
        }
    }

    func cancelTaskReminder(taskId: UUID) {
        var allIDs = Self.allReminderIntervals.map { "reminder-\(taskId.uuidString)-\($0.minutes)" }
        allIDs.append("reminder-\(taskId.uuidString)")
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: allIDs)
    }

    func scheduleAnnualReminder(reminderId: UUID, name: String, dueDate: Date, remindDaysBefore: [Int]) {
        let center = UNUserNotificationCenter.current()
        let allIDs = remindDaysBefore.map { "annual-\(reminderId.uuidString)-\($0)d" }
        center.removePendingNotificationRequests(withIdentifiers: allIDs)

        for days in remindDaysBefore {
            guard let reminderDate = Calendar.current.date(byAdding: .day, value: -days, to: dueDate),
                  reminderDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Upcoming Reminder"
            content.body = "\"\(name)\" is due in \(days) day\(days == 1 ? "" : "s")"
            content.sound = .default
            content.interruptionLevel = .timeSensitive

            var components = Calendar.current.dateComponents([.year, .month, .day], from: reminderDate)
            components.hour = 9
            components.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "annual-\(reminderId.uuidString)-\(days)d",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    func cancelAnnualReminder(reminderId: UUID) {
        let possibleDays = [1, 7, 14, 30]
        let ids = possibleDays.map { "annual-\(reminderId.uuidString)-\($0)d" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    func sendTaskReviewNotification(taskName: String, childName: String) {
        let title = "Task Submitted for Review"
        let body = "\(childName) completed \"\(taskName)\""
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "TASK_REVIEW"

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
        saveNotification(title: title, body: body, category: "TASK_REVIEW", senderName: childName)
    }

    func sendTaskApprovedNotification(taskName: String, childName: String, reward: Double) {
        let title = "Task Approved!"
        let body = reward > 0
            ? "Your task \"\(taskName)\" was approved! You earned \(Int(reward)) coins."
            : "Your task \"\(taskName)\" was approved!"
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
        saveNotification(title: title, body: body, category: "TASK_APPROVED")
    }

    func sendTaskRejectedNotification(taskName: String, childName: String) {
        let title = "Task Needs Redo"
        let body = "Your task \"\(taskName)\" was sent back. Please try again."
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
        saveNotification(title: title, body: body, category: "TASK_REJECTED")
    }

    func sendTaskAssignedNotification(taskName: String, assignerName: String) {
        let title = "New Task Assigned"
        let body = assignerName.isEmpty
            ? taskName
            : "\(assignerName) assigned \"\(taskName)\" to you"
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound(named: UNNotificationSoundName("reminder.wav"))
        content.categoryIdentifier = "TASK_ASSIGNED"
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(identifier: "assigned-\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
        saveNotification(title: title, body: body, category: "TASK_ASSIGNED", senderName: assignerName)
    }

    func deliverBeepNotification(title: String, body: String, category: String, senderName: String = "") {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound(named: UNNotificationSoundName("reminder.wav"))
        content.categoryIdentifier = category
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(identifier: "beep-\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
        saveNotification(title: title, body: body, category: category, senderName: senderName)
    }

    func sendTransportNotification(taskName: String, assignedTo: String, transportType: String, dueDate: Date) {
        let typeLabel: String
        switch transportType {
        case "pickup": typeLabel = "Pickup"
        case "dropoff": typeLabel = "Drop-off"
        case "both": typeLabel = "Pickup & Drop-off"
        default: return
        }
        let title = "\(typeLabel) Needed"
        let timeStr = dueDate.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        let body = "\(assignedTo) needs \(typeLabel.lowercased()) for \"\(taskName)\" at \(timeStr)"
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound(named: UNNotificationSoundName("reminder.wav"))
        content.categoryIdentifier = "TRANSPORT_NEEDED"
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(identifier: "transport-\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
        saveNotification(title: title, body: body, category: "TRANSPORT_NEEDED", senderName: assignedTo)
    }

    func sendPickupNotification(childName: String) {
        let title = "Pickup Request!"
        let body = "\(childName) wants to be picked up in 5 minutes!"
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound(named: UNNotificationSoundName("pickup.wav"))
        content.categoryIdentifier = "PICKUP_REQUEST"
        content.interruptionLevel = .timeSensitive
        content.userInfo = ["childName": childName]

        let request = UNNotificationRequest(identifier: "pickup-\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
        saveNotification(title: title, body: body, category: "PICKUP_REQUEST", senderName: childName)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let category = response.notification.request.content.categoryIdentifier

        if category == "TASK_REVIEW" {
            DispatchQueue.main.async {
                self.showPendingApprovals = true
            }
        }

        if category == "TASK_REMINDER",
           response.actionIdentifier == UNNotificationDefaultActionIdentifier,
           let spokenText = response.notification.request.content.userInfo["spokenText"] as? String {
            DispatchQueue.main.async { self.speakReminder(spokenText) }
        }

        if response.actionIdentifier == Self.pickupAckActionID {
            let childName = response.notification.request.content.userInfo["childName"] as? String ?? ""
            DispatchQueue.main.async {
                self.pickupAckChildName = childName
                self.onPickupAcknowledged?(childName)
            }
        }

        if response.actionIdentifier == Self.snoozeActionID {
            let original = response.notification.request
            let content = original.content.mutableCopy() as! UNMutableNotificationContent
            content.title = "Reminder (Snoozed)"
            content.interruptionLevel = .timeSensitive

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: Self.snoozeDuration,
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: "snooze-\(original.identifier)-\(UUID().uuidString)",
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request)
        }

        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let category = notification.request.content.categoryIdentifier
        if category == "TASK_REMINDER" {
            if let spokenText = notification.request.content.userInfo["spokenText"] as? String {
                DispatchQueue.main.async { self.speakReminder(spokenText) }
            } else {
                SoundManager.shared.playReminderBeep()
            }
            completionHandler([.banner, .list])
        } else if category == "TASK_ASSIGNED" {
            SoundManager.shared.playReminderBeep()
            completionHandler([.banner, .list])
        } else {
            completionHandler([.banner, .sound, .list])
        }
    }

    // MARK: - Daily Morning Summary

    private static let dailySummaryID = "daily-morning-summary"

    private static let noTaskMessages = [
        "No tasks today — a perfect day to create something phenomenal!",
        "Your slate is clean! What amazing thing will you do today?",
        "Zero tasks, infinite possibilities. Make today count!",
        "Nothing on the list — the world is yours today!",
        "A fresh day with no tasks. Dream big and go for it!",
        "All clear! Use today to do something that makes you proud.",
        "No tasks? No problem. Today's yours to own!",
    ]

    func scheduleDailySummary(tasks: [Item], userName: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.dailySummaryID])

        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let startOfTomorrow = calendar.startOfDay(for: tomorrow)
        let endOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfTomorrow)!

        let tomorrowTasks = tasks.filter { task in
            !task.isArchived && task.isOpen
            && task.targetDate >= startOfTomorrow
            && task.targetDate < endOfTomorrow
            && (task.assignedTo == userName || task.assignedTo.isEmpty)
        }

        let content = UNMutableNotificationContent()
        let greeting = userName.isEmpty ? "Your Day Ahead" : "Your Day Ahead, \(userName)"

        if tomorrowTasks.isEmpty {
            content.title = greeting
            content.body = Self.noTaskMessages.randomElement()!
        } else {
            let count = tomorrowTasks.count
            content.title = "\(greeting) — \(count) task\(count == 1 ? "" : "s") today"

            let previews = tomorrowTasks.prefix(3).map { "• \($0.name)" }
            var body = previews.joined(separator: "\n")
            if tomorrowTasks.count > 3 {
                body += "\n  ...and \(tomorrowTasks.count - 3) more"
            }
            let totalCoins = tomorrowTasks.reduce(0) { $0 + Int($1.reward) }
            if totalCoins > 0 {
                body += "\n⭐ \(totalCoins) coins up for grabs!"
            }
            content.body = body
        }

        content.sound = .default
        content.interruptionLevel = .active

        var triggerComponents = DateComponents()
        triggerComponents.hour = 7
        triggerComponents.minute = 30
        let triggerDate = calendar.nextDate(after: Date(), matching: triggerComponents, matchingPolicy: .nextTime)!
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate),
            repeats: false
        )

        let request = UNNotificationRequest(identifier: Self.dailySummaryID, content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Local Notification History

    struct LocalNotification: Codable, Identifiable {
        let id: String
        let title: String
        let body: String
        let category: String
        let senderAvatar: String
        let senderName: String
        let createdAt: Date
    }

    private static let storageKey = "localNotificationHistory"

    func savedNotifications() -> [LocalNotification] {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let items = try? JSONDecoder().decode([LocalNotification].self, from: data) else {
            return []
        }
        return items.sorted { $0.createdAt > $1.createdAt }
    }

    func saveNotification(title: String, body: String, category: String, senderAvatar: String = "", senderName: String = "") {
        var items = savedNotifications()
        let notif = LocalNotification(
            id: UUID().uuidString,
            title: title,
            body: body,
            category: category,
            senderAvatar: senderAvatar,
            senderName: senderName,
            createdAt: Date()
        )
        items.insert(notif, at: 0)
        if items.count > 100 { items = Array(items.prefix(100)) }
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    func deleteLocalNotification(id: String) {
        var items = savedNotifications()
        items.removeAll { $0.id == id }
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    func clearAllLocalNotifications() {
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    var localNotificationCount: Int {
        savedNotifications().count
    }
}
