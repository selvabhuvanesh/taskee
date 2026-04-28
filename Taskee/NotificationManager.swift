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
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
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
        content.sound = .default
        content.categoryIdentifier = "TASK_REMINDER"

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
        let content = UNMutableNotificationContent()
        content.title = "Task Submitted for Review"
        content.body = "\(childName) completed \"\(taskName)\""
        content.sound = .default
        content.categoryIdentifier = "TASK_REVIEW"

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func sendTaskApprovedNotification(taskName: String, childName: String, reward: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Task Approved!"
        content.body = reward > 0
            ? "Your task \"\(taskName)\" was approved! You earned \(Int(reward)) coins."
            : "Your task \"\(taskName)\" was approved!"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func sendTaskRejectedNotification(taskName: String, childName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Task Needs Redo"
        content.body = "Your task \"\(taskName)\" was sent back. Please try again."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func sendPickupNotification(childName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Pickup Request!"
        content.body = "\(childName) wants to be picked up in 5 minutes!"
        content.sound = .default
        content.categoryIdentifier = "PICKUP_REQUEST"

        let request = UNNotificationRequest(
            identifier: "pickup-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
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
        completionHandler([.banner, .sound])
    }
}
