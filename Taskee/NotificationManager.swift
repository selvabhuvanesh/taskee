//
//  NotificationManager.swift
//  Taskee
//

import Foundation
import UserNotifications

@Observable
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    var showPendingApprovals = false
    private static let snoozeActionID = "SNOOZE_ACTION"
    private static let dismissActionID = "DISMISS_ACTION"
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

        let pickup = UNNotificationCategory(
            identifier: "PICKUP_REQUEST",
            actions: [],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([taskReminder, taskReview, pickup])
    }

    func scheduleTaskReminder(taskId: UUID, taskName: String, assignedTo: String, dueDate: Date) {
        let reminderDate = dueDate.addingTimeInterval(-30 * 60)
        guard reminderDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Task Due Soon"
        content.body = assignedTo.isEmpty
            ? "\"\(taskName)\" is due in 30 minutes"
            : "\"\(taskName)\" assigned to \(assignedTo) is due in 30 minutes"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("reminder.wav"))
        content.categoryIdentifier = "TASK_REMINDER"
        content.interruptionLevel = .timeSensitive

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "reminder-\(taskId.uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func cancelTaskReminder(taskId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["reminder-\(taskId.uuidString)"]
        )
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

    func sendPickupNotification(childName: String) {
        let title = "Pickup Request!"
        let body = "\(childName) wants to be picked up in 5 minutes!"
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound(named: UNNotificationSoundName("pickup.wav"))
        content.categoryIdentifier = "PICKUP_REQUEST"
        content.interruptionLevel = .timeSensitive

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
        if category == "TASK_REMINDER" || category == "TASK_ASSIGNED" {
            SoundManager.shared.playReminderBeep()
            completionHandler([.banner, .list])
        } else {
            completionHandler([.banner, .sound, .list])
        }
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
