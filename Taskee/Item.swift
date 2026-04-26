//
//  Item.swift
//  Taskee
//
//  Created by Selva Bhuvanesh on 4/25/26.
//

import Foundation
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

    init(name: String, targetDate: Date, assignedTo: String = "", reward: Double = 0, status: String = "open", createdByChild: Bool = false) {
        self.id = UUID()
        self.name = name
        self.targetDate = targetDate
        self.assignedTo = assignedTo
        self.reward = reward
        self.status = status
        self.createdByChild = createdByChild
        self.isArchived = false
    }

    var isOpen: Bool { status == "open" }
    var isInReview: Bool { status == "inReview" }
    var isApproved: Bool { status == "approved" }

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
    var name: String
    var memberRole: String
    var avatar: String
    var isAccepted: Bool
    var totalEarned: Double

    init(name: String, memberRole: String = "child", avatar: String = "person.circle.fill", isAccepted: Bool = true, totalEarned: Double = 0) {
        self.name = name
        self.memberRole = memberRole
        self.avatar = avatar
        self.isAccepted = isAccepted
        self.totalEarned = totalEarned
    }

    var isParent: Bool { memberRole == "parent" }
    var isChild: Bool { memberRole == "child" }
}

let avatarOptions = [
    "person.circle.fill", "person.crop.circle.fill",
    "figure.stand", "figure.walk", "figure.run",
    "face.smiling.inverse", "star.circle.fill", "heart.circle.fill",
    "flame.circle.fill", "bolt.circle.fill", "leaf.circle.fill",
    "moon.circle.fill", "sun.max.circle.fill", "cloud.circle.fill",
    "paintpalette.fill", "gamecontroller.fill",
    "basketball.fill", "music.note",
    "book.circle.fill", "graduationcap.circle.fill"
]
