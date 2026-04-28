//
//  Item.swift
//  Taskee
//
//  Created by Selva Bhuvanesh on 4/25/26.
//

import Foundation
import SwiftUI
import SwiftData

@Model
final class Item {
    var id: UUID
    var name: String
    var targetDate: Date
    var assignedTo: String
    var reward: Double
    // "open", "inReview", "approved"
    var status: String
    var createdByChild: Bool
    var isArchived: Bool
    var isRecurring: Bool

    init(id: UUID = UUID(), name: String, targetDate: Date, assignedTo: String = "", reward: Double = 0, status: String = "open", createdByChild: Bool = false, isRecurring: Bool = false) {
        self.id = id
        self.name = name
        self.targetDate = targetDate
        self.assignedTo = assignedTo
        self.reward = reward
        self.status = status
        self.createdByChild = createdByChild
        self.isArchived = false
        self.isRecurring = isRecurring
    }

    var isOpen: Bool { status == "open" }
    var isInReview: Bool { status == "inReview" }
    var isApproved: Bool { status == "approved" }

    var isDueInFuture: Bool {
        !Calendar.current.isDateInToday(targetDate) && targetDate > Date()
    }

    var canComplete: Bool {
        !isRecurring || !isDueInFuture
    }

    var dueDateLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(targetDate) {
            return "Today"
        } else if calendar.isDateInTomorrow(targetDate) {
            return "Tomorrow"
        } else {
            return targetDate.formatted(.dateTime.weekday(.wide).month(.wide).day())
        }
    }
}

@Model
final class FamilyMember {
    var id: UUID = UUID()
    var name: String
    var memberRole: String
    var avatar: String
    var isAccepted: Bool
    var totalEarned: Double
    var appleUserID: String

    init(id: UUID = UUID(), name: String, memberRole: String = "child", avatar: String = "star.fill", isAccepted: Bool = true, totalEarned: Double = 0, appleUserID: String = "") {
        self.id = id
        self.name = name
        self.memberRole = memberRole
        self.avatar = avatar
        self.isAccepted = isAccepted
        self.totalEarned = totalEarned
        self.appleUserID = appleUserID
    }

    var isParent: Bool { memberRole == "parent" }
    var isChild: Bool { memberRole == "child" }
}

@Model
final class RewardRedemption {
    var id: UUID
    var childName: String
    var coinAmount: Int
    var redemptionType: String
    var itemDescription: String
    var status: String
    var rejectReason: String
    var createdAt: Date
    var resolvedAt: Date?

    init(id: UUID = UUID(), childName: String, coinAmount: Int, redemptionType: String, itemDescription: String, status: String = "pending") {
        self.id = id
        self.childName = childName
        self.coinAmount = coinAmount
        self.redemptionType = redemptionType
        self.itemDescription = itemDescription
        self.status = status
        self.rejectReason = ""
        self.createdAt = Date()
        self.resolvedAt = nil
    }

    var isPending: Bool { status == "pending" }
    var isApproved: Bool { status == "approved" }
    var isRejected: Bool { status == "rejected" }
    var isFulfilled: Bool { status == "fulfilled" }

    var typeIcon: String {
        switch redemptionType {
        case "cash": return "banknote.fill"
        case "toy": return "teddybear.fill"
        case "experience": return "ticket.fill"
        case "screenTime": return "ipad.landscape"
        case "treat": return "cup.and.saucer.fill"
        default: return "gift.fill"
        }
    }

    var typeLabel: String {
        switch redemptionType {
        case "cash": return "Cash"
        case "toy": return "Toy"
        case "experience": return "Experience"
        case "screenTime": return "Screen Time"
        case "treat": return "Treat"
        default: return "Other"
        }
    }
}

let redemptionTypes = [
    ("cash", "Cash", "banknote.fill"),
    ("toy", "Toy", "teddybear.fill"),
    ("experience", "Experience", "ticket.fill"),
    ("screenTime", "Screen Time", "ipad.landscape"),
    ("treat", "Treat", "cup.and.saucer.fill"),
    ("other", "Other", "gift.fill"),
]

// MARK: - Recurrence

enum RecurrenceType: String, CaseIterable {
    case none = "None"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
}

let weekdayLabels = ["S", "M", "T", "W", "T", "F", "S"]

// MARK: - Task Templates

struct TaskTemplate: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let suggestedRecurrence: RecurrenceType
    let suggestedReward: Int
}

let taskTemplates = [
    TaskTemplate(name: "Study Time", icon: "book.fill", color: calmAccent, suggestedRecurrence: .daily, suggestedReward: 5),
    TaskTemplate(name: "Take Out Trash", icon: "trash.fill", color: .green, suggestedRecurrence: .weekly, suggestedReward: 3),
    TaskTemplate(name: "Clean Your Room", icon: "sparkles", color: .purple, suggestedRecurrence: .weekly, suggestedReward: 10),
    TaskTemplate(name: "Read a Book", icon: "book.closed.fill", color: .orange, suggestedRecurrence: .daily, suggestedReward: 5),
    TaskTemplate(name: "Walk the Dog", icon: "dog.fill", color: .cyan, suggestedRecurrence: .daily, suggestedReward: 5),
]

// MARK: - Avatars

let avatarOptions = [
    "star.fill", "heart.fill",
    "flame.fill", "bolt.fill",
    "moon.fill", "sun.max.fill",
    "gamecontroller.fill", "paintpalette.fill",
    "leaf.fill", "sparkles"
]

// MARK: - Accent Color

let calmAccent = Color.blue

func avatarColor(for avatar: String) -> Color {
    switch avatar {
    case "star.fill": return .yellow
    case "heart.fill": return .pink
    case "flame.fill": return .orange
    case "bolt.fill": return .cyan
    case "moon.fill": return .indigo
    case "sun.max.fill": return .yellow
    case "gamecontroller.fill": return .purple
    case "paintpalette.fill": return .mint
    case "leaf.fill": return .green
    case "sparkles": return .teal
    default: return calmAccent
    }
}
