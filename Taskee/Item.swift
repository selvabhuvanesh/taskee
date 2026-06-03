//
//  Item.swift
//  Taskee
//
//  Created by Selva Bhuvanesh on 4/25/26.
//

import Foundation
import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

@Model
final class Item {
    var id: UUID
    var name: String
    var targetDate: Date
    var assignedTo: String
    var reward: Double
    // "open", "inReview", "approved", "missed", "cancelled"
    var status: String
    var createdByChild: Bool
    var isArchived: Bool
    var isRecurring: Bool
    var giftText: String
    var giftRevealed: Bool
    var createdBy: String
    var createdByID: String
    var lastRemindedAt: Date?
    var transportType: String = "none"
    var projectId: String = ""
    var goalId: String = ""

    var belongsToGoal: Bool { !goalId.isEmpty }

    init(id: UUID = UUID(), name: String, targetDate: Date, assignedTo: String = "", reward: Double = 0, status: String = "open", createdByChild: Bool = false, isRecurring: Bool = false, giftText: String = "", createdBy: String = "", createdByID: String = "", transportType: String = "none", projectId: String = "", goalId: String = "") {
        self.id = id
        self.name = name
        self.targetDate = targetDate
        self.assignedTo = assignedTo
        self.reward = reward
        self.status = status
        self.createdByChild = createdByChild
        self.isArchived = false
        self.isRecurring = isRecurring
        self.giftText = giftText
        self.giftRevealed = false
        self.createdBy = createdBy
        self.createdByID = createdByID
        self.lastRemindedAt = nil
        self.transportType = transportType
        self.projectId = projectId
        self.goalId = goalId
    }

    var hasGift: Bool { !giftText.isEmpty }
    var belongsToProject: Bool { !projectId.isEmpty }
    var needsTransport: Bool { transportType != "none" }

    var emoji: String {
        let lower = name.lowercased()
        for (keyword, emoji) in Self.emojiMap {
            if lower.contains(keyword) { return emoji }
        }
        return "✅"
    }

    private static let emojiMap: [(String, String)] = [
        // School & learning
        ("homework", "📚"), ("study", "📖"), ("read", "📕"), ("book", "📗"),
        ("math", "🔢"), ("science", "🔬"), ("history", "🏛️"), ("essay", "✍️"),
        ("school", "🏫"), ("class", "🎓"), ("exam", "📝"), ("test", "📝"),
        ("project", "📋"), ("assignment", "📄"), ("practice", "🎯"),
        ("tutor", "👩‍🏫"), ("lesson", "📓"), ("learn", "💡"),

        // Chores & cleaning
        ("clean", "🧹"), ("vacuum", "🧹"), ("sweep", "🧹"), ("mop", "🧽"),
        ("dishes", "🍽️"), ("laundry", "👕"), ("wash", "🧼"), ("fold", "👔"),
        ("tidy", "🧹"), ("organize", "📦"), ("trash", "🗑️"), ("garbage", "🗑️"),
        ("recycle", "♻️"), ("dust", "✨"), ("scrub", "🧽"), ("wipe", "🧻"),

        // Cooking & food
        ("cook", "👩‍🍳"), ("dinner", "🍽️"), ("lunch", "🥪"), ("breakfast", "🥣"),
        ("snack", "🍎"), ("bake", "🧁"), ("meal", "🍲"), ("grocery", "🛒"),
        ("shopping", "🛍️"), ("eat", "🍴"),

        // Outdoor & sports
        ("walk", "🚶"), ("run", "🏃"), ("exercise", "💪"), ("gym", "🏋️"),
        ("swim", "🏊"), ("bike", "🚲"), ("soccer", "⚽"), ("football", "🏈"),
        ("basketball", "🏀"), ("baseball", "⚾"), ("tennis", "🎾"),
        ("sport", "🏅"), ("dance", "💃"), ("yoga", "🧘"), ("hike", "🥾"),
        ("play", "🎮"), ("game", "🎲"), ("outside", "🌳"), ("park", "🌿"),
        ("garden", "🌱"), ("water plant", "🪴"), ("plant", "🌱"), ("lawn", "🌿"),
        ("mow", "🌿"),

        // Pets
        ("dog", "🐕"), ("cat", "🐈"), ("pet", "🐾"), ("feed", "🥣"),
        ("fish", "🐟"), ("hamster", "🐹"), ("bird", "🐦"),

        // Music & arts
        ("piano", "🎹"), ("guitar", "🎸"), ("music", "🎵"), ("sing", "🎤"),
        ("drum", "🥁"), ("violin", "🎻"), ("art", "🎨"), ("draw", "✏️"),
        ("paint", "🖌️"), ("craft", "✂️"), ("color", "🖍️"),

        // Personal care
        ("brush teeth", "🪥"), ("brushing", "🪥"), ("teeth", "🪥"), ("shower", "🚿"), ("bath", "🛁"),
        ("hair", "💇"), ("bed", "🛏️"), ("sleep", "😴"), ("nap", "💤"),
        ("wake", "⏰"), ("dress", "👗"), ("clothes", "👚"),
        ("mind detox", "🧠"), ("detox", "🧠"), ("meditat", "🧘"),

        // Transport & errands
        ("drive", "🚗"), ("pick up", "🚗"), ("pickup", "🚗"), ("drop off", "🚗"),
        ("dropoff", "🚗"), ("school bus", "🚌"), ("bus", "🚌"),
        ("dentist", "🦷"), ("doctor", "🏥"), ("health check", "🩺"),
        ("appointment", "📅"), ("errand", "🏃"),

        // Home maintenance
        ("hvac", "🌬️"), ("filter", "🌬️"), ("deep clean", "🧼"), ("car wash", "🚗"), ("car clean", "🧽"),

        // Digital & screen
        ("screen", "📱"), ("phone", "📱"), ("computer", "💻"), ("email", "📧"),
        ("call", "📞"), ("video", "📹"), ("movie", "🎬"), ("tv", "📺"),

        // Social & family
        ("friend", "👫"), ("birthday", "🎂"), ("party", "🎉"), ("gift", "🎁"),
        ("visit", "🏠"), ("meet", "🤝"), ("help", "🤲"), ("share", "💝"),
        ("thank", "🙏"), ("letter", "✉️"), ("card", "💌"),

        // Money & work
        ("save", "💰"), ("money", "💵"), ("earn", "💰"), ("chore", "📋"),
        ("job", "💼"), ("work", "⚒️"), ("task", "📌"),

        // Travel
        ("pack", "🧳"), ("travel", "✈️"), ("trip", "🗺️"), ("camp", "⛺"),
    ]
    var needsPickup: Bool { transportType == "pickup" || transportType == "both" }
    var needsDropoff: Bool { transportType == "dropoff" || transportType == "both" }

    var transportIcon: String {
        switch transportType {
        case "pickup": return "car.fill"
        case "dropoff": return "car.side.fill"
        case "both": return "car.2.fill"
        default: return "car"
        }
    }

    var transportLabel: String {
        switch transportType {
        case "pickup": return "Pickup"
        case "dropoff": return "Drop-off"
        case "both": return "Pickup & Drop-off"
        default: return ""
        }
    }

    static func nextTransportType(after current: String) -> String {
        switch current {
        case "none": return "pickup"
        case "pickup": return "dropoff"
        case "dropoff": return "both"
        case "both": return "none"
        default: return "none"
        }
    }

    var isOpen: Bool { status == "open" }
    var isInReview: Bool { status == "inReview" }
    var isApproved: Bool { status == "approved" }
    var isMissed: Bool { status == "missed" }
    var isCancelled: Bool { status == "cancelled" }

    var isPastDue: Bool {
        targetDate < Date() && !Calendar.current.isDateInToday(targetDate)
    }

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

extension UTType {
    static let taskItem = UTType(exportedAs: "com.taskee.taskitem")
}

struct TaskTransfer: Codable, Transferable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .taskItem)
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
    var lastPickupAt: Date?
    var lastPickupAckAt: Date?
    var lastPickupAckBy: String

    init(id: UUID = UUID(), name: String, memberRole: String = "child", avatar: String = "av01", isAccepted: Bool = true, totalEarned: Double = 0, appleUserID: String = "") {
        self.id = id
        self.name = name
        self.memberRole = memberRole
        self.avatar = avatar
        self.isAccepted = isAccepted
        self.totalEarned = totalEarned
        self.appleUserID = appleUserID
        self.lastPickupAt = nil
        self.lastPickupAckAt = nil
        self.lastPickupAckBy = ""
    }

    var isParent: Bool { memberRole == "parent" }
    var isChild: Bool { memberRole == "child" }

    func recomputeEarned(from tasks: [Item], excluding taskID: UUID? = nil) {
        totalEarned = tasks
            .filter { $0.id != taskID && $0.assignedTo == name && $0.isApproved && $0.reward > 0 }
            .reduce(0.0) { $0 + $1.reward }
    }
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

@Model
final class SurpriseGift {
    var id: UUID
    var childName: String
    var giftDescription: String
    var taskName: String
    var earnedDate: Date
    var isRedeemed: Bool

    init(id: UUID = UUID(), childName: String, giftDescription: String, taskName: String, earnedDate: Date = Date()) {
        self.id = id
        self.childName = childName
        self.giftDescription = giftDescription
        self.taskName = taskName
        self.earnedDate = earnedDate
        self.isRedeemed = false
    }
}

@Model
final class WishListItem {
    var id: UUID
    var name: String
    var ownerAppleUserID: String
    var ownerName: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, ownerAppleUserID: String, ownerName: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.ownerAppleUserID = ownerAppleUserID
        self.ownerName = ownerName
        self.createdAt = createdAt
    }
}

@Model
final class ShoppingItem {
    var id: UUID
    var name: String
    var addedBy: String
    var isBought: Bool
    var createdAt: Date

    init(id: UUID = UUID(), name: String, addedBy: String, isBought: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.addedBy = addedBy
        self.isBought = isBought
        self.createdAt = createdAt
    }
}

@Model
final class ChatMessage {
    var id: UUID
    var senderName: String
    var senderAvatar: String
    var senderAppleUserID: String
    var text: String
    var reactions: String
    var sentAt: Date
    @Attribute(.externalStorage) var attachmentData: Data?
    var attachmentName: String
    var attachmentType: String

    init(id: UUID = UUID(), senderName: String, senderAvatar: String, senderAppleUserID: String, text: String, sentAt: Date = Date(), attachmentData: Data? = nil, attachmentName: String = "", attachmentType: String = "image") {
        self.id = id
        self.senderName = senderName
        self.senderAvatar = senderAvatar
        self.senderAppleUserID = senderAppleUserID
        self.text = text
        self.reactions = ""
        self.sentAt = sentAt
        self.attachmentData = attachmentData
        self.attachmentName = attachmentName
        self.attachmentType = attachmentType
    }

    var hasAttachment: Bool { attachmentData != nil }
    var isImageAttachment: Bool { attachmentType == "image" && hasAttachment }
    var isVideoAttachment: Bool { attachmentType == "video" && hasAttachment }
    var isFileAttachment: Bool { attachmentType == "file" && hasAttachment }

    var reactionDict: [String: [String]] {
        guard !reactions.isEmpty, let data = reactions.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: [String]].self, from: data) else { return [:] }
        return dict
    }

    func setReactions(_ dict: [String: [String]]) {
        if let data = try? JSONEncoder().encode(dict), let str = String(data: data, encoding: .utf8) {
            reactions = str
        }
    }

    func toggleReaction(_ emoji: String, by userName: String) {
        var dict = reactionDict
        var users = dict[emoji] ?? []
        if users.contains(userName) {
            users.removeAll { $0 == userName }
        } else {
            users.append(userName)
        }
        if users.isEmpty {
            dict.removeValue(forKey: emoji)
        } else {
            dict[emoji] = users
        }
        setReactions(dict)
    }
}

// MARK: - Annual Reminders

enum ReminderCategory: String, CaseIterable, Codable {
    case vehicle = "Vehicle"
    case insurance = "Insurance"
    case medical = "Medical"
    case education = "Education"
    case financial = "Financial"
    case home = "Home"
    case subscriptions = "Subscriptions"
    case legalID = "Legal/ID"
    case seasonal = "Seasonal"

    var icon: String {
        switch self {
        case .vehicle: return "car.fill"
        case .insurance: return "shield.fill"
        case .medical: return "cross.case.fill"
        case .education: return "graduationcap.fill"
        case .financial: return "banknote.fill"
        case .home: return "house.fill"
        case .subscriptions: return "arrow.triangle.2.circlepath"
        case .legalID: return "doc.text.fill"
        case .seasonal: return "leaf.fill"
        }
    }

    var color: Color {
        switch self {
        case .vehicle: return .blue
        case .insurance: return .green
        case .medical: return .red
        case .education: return .orange
        case .financial: return .mint
        case .home: return .purple
        case .subscriptions: return .cyan
        case .legalID: return .indigo
        case .seasonal: return .yellow
        }
    }
}

enum ReminderRepeat: String, CaseIterable, Codable {
    case none = "None"
    case quarterly = "Quarterly"
    case halfYearly = "Half-Yearly"
    case yearly = "Yearly"

    var label: String { rawValue }

    var monthsToAdd: Int {
        switch self {
        case .none: return 0
        case .quarterly: return 3
        case .halfYearly: return 6
        case .yearly: return 12
        }
    }

    var icon: String {
        switch self {
        case .none: return "calendar"
        case .quarterly: return "calendar.badge.clock"
        case .halfYearly: return "calendar.badge.clock"
        case .yearly: return "repeat"
        }
    }
}

@Model
final class AnnualReminder {
    var id: UUID
    var name: String
    var category: String
    var dueDate: Date
    var repeatYearly: Bool
    var repeatFrequency: String = "Yearly"
    var remindDaysBefore: String
    var notes: String
    var isDone: Bool
    var createdAt: Date

    init(id: UUID = UUID(), name: String, category: String, dueDate: Date, repeatYearly: Bool = true, repeatFrequency: String = "Yearly", remindDaysBefore: String = "[30,14,7]", notes: String = "", isDone: Bool = false) {
        self.id = id
        self.name = name
        self.category = category
        self.dueDate = dueDate
        self.repeatYearly = repeatYearly
        self.repeatFrequency = repeatFrequency
        self.remindDaysBefore = remindDaysBefore
        self.notes = notes
        self.isDone = isDone
        self.createdAt = Date()
    }

    var categoryEnum: ReminderCategory {
        ReminderCategory(rawValue: category) ?? .home
    }

    var frequencyEnum: ReminderRepeat {
        ReminderRepeat(rawValue: repeatFrequency) ?? (repeatYearly ? .yearly : .none)
    }

    var repeats: Bool {
        frequencyEnum != .none
    }

    var remindDays: [Int] {
        guard let data = remindDaysBefore.data(using: .utf8),
              let days = try? JSONDecoder().decode([Int].self, from: data) else { return [30, 14, 7] }
        return days
    }

    func setRemindDays(_ days: [Int]) {
        if let data = try? JSONEncoder().encode(days), let str = String(data: data, encoding: .utf8) {
            remindDaysBefore = str
        }
    }

    func advanceToNextDue() {
        let months = frequencyEnum.monthsToAdd
        guard months > 0 else { return }
        if let next = Calendar.current.date(byAdding: .month, value: months, to: dueDate) {
            dueDate = next
        }
    }

    var daysUntilDue: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: dueDate)).day ?? 0
    }

    var isDueSoon: Bool {
        daysUntilDue >= 0 && daysUntilDue <= 30 && !isDone
    }

    var isOverdue: Bool {
        daysUntilDue < 0 && !isDone
    }
}

struct ReminderTemplate: Identifiable {
    let id = UUID()
    let name: String
    let category: ReminderCategory
}

let reminderTemplates: [ReminderCategory: [ReminderTemplate]] = [
    .vehicle: [
        ReminderTemplate(name: "Vehicle Registration", category: .vehicle),
        ReminderTemplate(name: "Car Insurance", category: .vehicle),
        ReminderTemplate(name: "Emissions Test", category: .vehicle),
        ReminderTemplate(name: "Tyre Rotation", category: .vehicle),
        ReminderTemplate(name: "Oil Change / Service", category: .vehicle),
    ],
    .insurance: [
        ReminderTemplate(name: "Health Insurance", category: .insurance),
        ReminderTemplate(name: "Home Insurance", category: .insurance),
        ReminderTemplate(name: "Life Insurance", category: .insurance),
        ReminderTemplate(name: "Dental Insurance", category: .insurance),
    ],
    .medical: [
        ReminderTemplate(name: "Annual Physical", category: .medical),
        ReminderTemplate(name: "Dental Checkup", category: .medical),
        ReminderTemplate(name: "Eye Exam", category: .medical),
        ReminderTemplate(name: "Vaccination", category: .medical),
        ReminderTemplate(name: "Pet Vet Visit", category: .medical),
    ],
    .education: [
        ReminderTemplate(name: "School Fee Payment", category: .education),
        ReminderTemplate(name: "Tuition Deadline", category: .education),
        ReminderTemplate(name: "School Enrollment", category: .education),
    ],
    .financial: [
        ReminderTemplate(name: "Tax Filing", category: .financial),
        ReminderTemplate(name: "Property Tax", category: .financial),
        ReminderTemplate(name: "Credit Card Annual Fee", category: .financial),
        ReminderTemplate(name: "Estimated Tax Payment", category: .financial),
    ],
    .home: [
        ReminderTemplate(name: "HVAC Service", category: .home),
        ReminderTemplate(name: "Pest Control", category: .home),
        ReminderTemplate(name: "Gutter Cleaning", category: .home),
        ReminderTemplate(name: "Fire Extinguisher Check", category: .home),
        ReminderTemplate(name: "Smoke Detector Battery", category: .home),
    ],
    .subscriptions: [
        ReminderTemplate(name: "Domain Renewal", category: .subscriptions),
        ReminderTemplate(name: "Software License", category: .subscriptions),
        ReminderTemplate(name: "Gym Membership", category: .subscriptions),
        ReminderTemplate(name: "Club Membership", category: .subscriptions),
    ],
    .legalID: [
        ReminderTemplate(name: "Passport Renewal", category: .legalID),
        ReminderTemplate(name: "Driver's License", category: .legalID),
        ReminderTemplate(name: "Visa Renewal", category: .legalID),
        ReminderTemplate(name: "Professional License", category: .legalID),
    ],
    .seasonal: [
        ReminderTemplate(name: "AC Service (Summer)", category: .seasonal),
        ReminderTemplate(name: "Heater Service (Winter)", category: .seasonal),
        ReminderTemplate(name: "Garden / Lawn Prep", category: .seasonal),
    ],
]

// MARK: - Family Projects

enum ProjectCategory: String, CaseIterable, Codable {
    case home = "Home"
    case travel = "Travel"
    case pet = "Pet"
    case fitness = "Fitness"
    case education = "Education"
    case fun = "Fun"
    case finance = "Finance"

    var icon: String {
        switch self {
        case .home: return "hammer.fill"
        case .travel: return "airplane"
        case .pet: return "pawprint.fill"
        case .fitness: return "figure.run"
        case .education: return "book.fill"
        case .fun: return "party.popper.fill"
        case .finance: return "chart.line.uptrend.xyaxis"
        }
    }

    var color: Color {
        switch self {
        case .home: return .orange
        case .travel: return .blue
        case .pet: return .brown
        case .fitness: return .green
        case .education: return .purple
        case .fun: return .pink
        case .finance: return .mint
        }
    }
}

@Model
final class FamilyProject {
    var id: UUID
    var name: String
    var descriptionText: String
    var category: String
    var status: String = "ideating"
    var createdBy: String
    var targetDate: Date?
    var createdAt: Date

    init(id: UUID = UUID(), name: String, descriptionText: String = "", category: String = "Home", status: String = "ideating", createdBy: String, targetDate: Date? = nil) {
        self.id = id
        self.name = name
        self.descriptionText = descriptionText
        self.category = category
        self.status = status
        self.createdBy = createdBy
        self.targetDate = targetDate
        self.createdAt = Date()
    }

    var categoryEnum: ProjectCategory {
        ProjectCategory(rawValue: category) ?? .home
    }

    var isIdeating: Bool { status == "ideating" }
    var isPlanning: Bool { status == "planning" }
    var isInProgress: Bool { status == "inProgress" }
    var isCompleted: Bool { status == "completed" }

    var statusLabel: String {
        switch status {
        case "ideating": return "Ideating"
        case "planning": return "Planning"
        case "inProgress": return "Executing"
        case "completed": return "Completed"
        default: return status
        }
    }

    var statusIcon: String {
        switch status {
        case "ideating": return "lightbulb.fill"
        case "planning": return "list.clipboard.fill"
        case "inProgress": return "bolt.fill"
        case "completed": return "checkmark.seal.fill"
        default: return "folder.fill"
        }
    }

    var statusColor: Color {
        switch status {
        case "ideating": return .yellow
        case "planning": return .blue
        case "inProgress": return .orange
        case "completed": return .green
        default: return .gray
        }
    }

    static let statusOrder = ["ideating", "planning", "inProgress", "completed"]

    func nextStatus() -> String? {
        guard let idx = Self.statusOrder.firstIndex(of: status), idx + 1 < Self.statusOrder.count else { return nil }
        return Self.statusOrder[idx + 1]
    }
}

@Model
final class ProjectIdea {
    var id: UUID
    var projectId: String
    var text: String
    var submittedBy: String
    var createdAt: Date

    init(id: UUID = UUID(), projectId: String, text: String, submittedBy: String) {
        self.id = id
        self.projectId = projectId
        self.text = text
        self.submittedBy = submittedBy
        self.createdAt = Date()
    }
}

@Model
final class ProjectVote {
    var id: UUID
    var ideaId: String
    var memberName: String
    var isUpvote: Bool

    init(id: UUID = UUID(), ideaId: String, memberName: String, isUpvote: Bool) {
        self.id = id
        self.ideaId = ideaId
        self.memberName = memberName
        self.isUpvote = isUpvote
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

// MARK: - Recurring Task Extension

struct RecurringTaskGroup: Identifiable {
    let id = UUID()
    let name: String
    let assignedTo: String
    let reward: Double
    let createdByChild: Bool
    let latestDate: Date
    let taskCount: Int
    let timeHour: Int
    let timeMinute: Int
    let weekdays: Set<Int>
    let frequency: RecurrenceType
}

struct RecurringTaskExtender {
    private static let lastExtensionKey = "lastRecurringExtensionDate"

    static func needsExtension() -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let lastExtension = UserDefaults.standard.double(forKey: lastExtensionKey)
        if lastExtension > 0 {
            let lastDate = Date(timeIntervalSince1970: lastExtension)
            if calendar.isDate(lastDate, equalTo: now, toGranularity: .month) {
                return false
            }
        }
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1),
                                        to: calendar.date(from: calendar.dateComponents([.year, .month], from: now))!)!
        let daysLeft = calendar.dateComponents([.day], from: now, to: endOfMonth).day ?? 30
        return daysLeft <= 7
    }

    static func markExtended() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastExtensionKey)
    }

    static func markDismissed() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastExtensionKey)
    }

    static func findRecurringGroups(from tasks: [Item]) -> [RecurringTaskGroup] {
        let recurring = tasks.filter { $0.isRecurring && !$0.isArchived }
        let grouped = Dictionary(grouping: recurring) { "\($0.name)|\($0.assignedTo)|\($0.createdByChild)" }
        let calendar = Calendar.current

        return grouped.compactMap { _, groupTasks in
            guard let latest = groupTasks.max(by: { $0.targetDate < $1.targetDate }) else { return nil }

            let now = Date()
            let endOfNextMonth = calendar.date(byAdding: DateComponents(month: 2),
                                                to: calendar.date(from: calendar.dateComponents([.year, .month], from: now))!)!
            if latest.targetDate >= endOfNextMonth { return nil }

            let weekdays = Set(groupTasks.map { calendar.component(.weekday, from: $0.targetDate) })
            let timeComps = calendar.dateComponents([.hour, .minute], from: latest.targetDate)

            let sortedDates = groupTasks.map(\.targetDate).sorted()
            let frequency: RecurrenceType
            if sortedDates.count >= 2 {
                let intervals = zip(sortedDates, sortedDates.dropFirst()).map {
                    calendar.dateComponents([.day], from: $0.0, to: $0.1).day ?? 0
                }
                let avgInterval = intervals.reduce(0, +) / max(intervals.count, 1)
                if avgInterval <= 1 { frequency = .daily }
                else if avgInterval <= 10 { frequency = .weekly }
                else { frequency = .monthly }
            } else {
                frequency = .daily
            }

            return RecurringTaskGroup(
                name: latest.name,
                assignedTo: latest.assignedTo,
                reward: latest.reward,
                createdByChild: latest.createdByChild,
                latestDate: latest.targetDate,
                taskCount: groupTasks.count,
                timeHour: timeComps.hour ?? 9,
                timeMinute: timeComps.minute ?? 0,
                weekdays: weekdays,
                frequency: frequency
            )
        }
    }

    static func generateExtensionDates(for group: RecurringTaskGroup, taskLimit: Int?) -> [Date] {
        let calendar = Calendar.current
        let now = Date()
        let startOfNextMonth = calendar.date(byAdding: DateComponents(month: 1),
                                              to: calendar.date(from: calendar.dateComponents([.year, .month], from: now))!)!
        let endOfNextMonth = calendar.date(byAdding: DateComponents(month: 2),
                                            to: calendar.date(from: calendar.dateComponents([.year, .month], from: now))!)!

        let startDate = max(group.latestDate.addingTimeInterval(86400), startOfNextMonth)
        var dates: [Date] = []

        switch group.frequency {
        case .daily:
            var current = startDate
            while current < endOfNextMonth {
                var comps = calendar.dateComponents([.year, .month, .day], from: current)
                comps.hour = group.timeHour
                comps.minute = group.timeMinute
                if let date = calendar.date(from: comps) {
                    dates.append(date)
                }
                current = calendar.date(byAdding: .day, value: 1, to: current)!
            }

        case .weekly:
            var current = startDate
            while current < endOfNextMonth {
                let weekday = calendar.component(.weekday, from: current)
                if group.weekdays.contains(weekday) {
                    var comps = calendar.dateComponents([.year, .month, .day], from: current)
                    comps.hour = group.timeHour
                    comps.minute = group.timeMinute
                    if let date = calendar.date(from: comps) {
                        dates.append(date)
                    }
                }
                current = calendar.date(byAdding: .day, value: 1, to: current)!
            }

        case .monthly:
            var comps = calendar.dateComponents([.year, .month, .day], from: group.latestDate)
            comps.month = calendar.component(.month, from: startOfNextMonth)
            comps.year = calendar.component(.year, from: startOfNextMonth)
            comps.hour = group.timeHour
            comps.minute = group.timeMinute
            if let date = calendar.date(from: comps), date < endOfNextMonth {
                dates.append(date)
            }

        case .none:
            break
        }

        if let limit = taskLimit, dates.count > limit {
            dates = Array(dates.prefix(limit))
        }

        return dates
    }
}

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

// MARK: - Task Dictionary

struct TaskDictionaryEntry: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
    let frequencyLabel: String
    let recurrence: RecurrenceType
    let suggestedReward: Int
}

struct TaskDictionaryCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let tasks: [TaskDictionaryEntry]
}

let taskDictionary: [TaskDictionaryCategory] = [
    TaskDictionaryCategory(name: "Morning Routine", icon: "sunrise.fill", color: .orange, tasks: [
        TaskDictionaryEntry(name: "Brush Teeth", emoji: "🪥", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 1),
        TaskDictionaryEntry(name: "Make Bed", emoji: "🛏️", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 2),
        TaskDictionaryEntry(name: "Get Dressed", emoji: "👕", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 1),
        TaskDictionaryEntry(name: "Eat Breakfast", emoji: "🥣", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 1),
        TaskDictionaryEntry(name: "Pack School Bag", emoji: "🎒", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 2),
        TaskDictionaryEntry(name: "Take Vitamins", emoji: "💊", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 1),
        TaskDictionaryEntry(name: "Wash Face", emoji: "🧴", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 1),
    ]),
    TaskDictionaryCategory(name: "School & Learning", icon: "graduationcap.fill", color: calmAccent, tasks: [
        TaskDictionaryEntry(name: "Do Homework", emoji: "📚", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 5),
        TaskDictionaryEntry(name: "Study for Test", emoji: "📝", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 8),
        TaskDictionaryEntry(name: "Read for 30 Minutes", emoji: "📖", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 5),
        TaskDictionaryEntry(name: "Practice Spelling", emoji: "✍️", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 3),
        TaskDictionaryEntry(name: "Practice Math", emoji: "🔢", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 4),
        TaskDictionaryEntry(name: "Complete Assignment", emoji: "📄", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 6),
        TaskDictionaryEntry(name: "Science Project", emoji: "🔬", frequencyLabel: "Monthly", recurrence: .monthly, suggestedReward: 15),
        TaskDictionaryEntry(name: "Book Report", emoji: "📗", frequencyLabel: "Monthly", recurrence: .monthly, suggestedReward: 10),
        TaskDictionaryEntry(name: "Practice Typing", emoji: "⌨️", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 3),
        TaskDictionaryEntry(name: "School Bus Time", emoji: "🚌", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 1),
    ]),
    TaskDictionaryCategory(name: "Household Chores", icon: "house.fill", color: .green, tasks: [
        TaskDictionaryEntry(name: "Clean Room", emoji: "🧹", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 10),
        TaskDictionaryEntry(name: "Take Out Trash", emoji: "🗑️", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 3),
        TaskDictionaryEntry(name: "Do Dishes", emoji: "🍽️", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 4),
        TaskDictionaryEntry(name: "Load Dishwasher", emoji: "🍽️", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 3),
        TaskDictionaryEntry(name: "Unload Dishwasher", emoji: "🍽️", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 3),
        TaskDictionaryEntry(name: "Vacuum Room", emoji: "🧹", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 5),
        TaskDictionaryEntry(name: "Sweep Floor", emoji: "🧹", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 4),
        TaskDictionaryEntry(name: "Mop Floor", emoji: "🧽", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 5),
        TaskDictionaryEntry(name: "Do Laundry", emoji: "👕", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 5),
        TaskDictionaryEntry(name: "Fold Clothes", emoji: "👔", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 4),
        TaskDictionaryEntry(name: "Put Away Groceries", emoji: "🛒", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 3),
        TaskDictionaryEntry(name: "Wipe Counters", emoji: "🧻", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 2),
        TaskDictionaryEntry(name: "Organize Closet", emoji: "📦", frequencyLabel: "Monthly", recurrence: .monthly, suggestedReward: 10),
        TaskDictionaryEntry(name: "Dust Furniture", emoji: "✨", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 4),
        TaskDictionaryEntry(name: "Clean Bathroom", emoji: "🧽", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 8),
        TaskDictionaryEntry(name: "Set the Table", emoji: "🍽️", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 2),
        TaskDictionaryEntry(name: "Clear the Table", emoji: "🍽️", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 2),
        TaskDictionaryEntry(name: "Take Out Recycling", emoji: "♻️", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 3),
        TaskDictionaryEntry(name: "Tidy Living Room", emoji: "🛋️", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 3),
        TaskDictionaryEntry(name: "Deep Cleaning", emoji: "🧼", frequencyLabel: "Monthly", recurrence: .monthly, suggestedReward: 15),
        TaskDictionaryEntry(name: "HVAC Filter Change", emoji: "🌬️", frequencyLabel: "Quarterly", recurrence: .monthly, suggestedReward: 5),
    ]),
    TaskDictionaryCategory(name: "Cooking & Meals", icon: "fork.knife", color: .red, tasks: [
        TaskDictionaryEntry(name: "Help Cook Dinner", emoji: "👩‍🍳", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 5),
        TaskDictionaryEntry(name: "Prepare Lunch Box", emoji: "🥪", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 3),
        TaskDictionaryEntry(name: "Make a Snack", emoji: "🍎", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 2),
        TaskDictionaryEntry(name: "Bake Something", emoji: "🧁", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 8),
        TaskDictionaryEntry(name: "Grocery Shopping", emoji: "🛒", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 5),
        TaskDictionaryEntry(name: "Meal Prep", emoji: "🍲", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 6),
    ]),
    TaskDictionaryCategory(name: "Outdoor & Yard", icon: "leaf.fill", color: Color(red: 0.2, green: 0.7, blue: 0.3), tasks: [
        TaskDictionaryEntry(name: "Mow the Lawn", emoji: "🌿", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 10),
        TaskDictionaryEntry(name: "Water Plants", emoji: "🪴", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 2),
        TaskDictionaryEntry(name: "Rake Leaves", emoji: "🍂", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 6),
        TaskDictionaryEntry(name: "Pull Weeds", emoji: "🌱", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 5),
        TaskDictionaryEntry(name: "Shovel Snow", emoji: "❄️", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 8),
        TaskDictionaryEntry(name: "Sweep Porch", emoji: "🧹", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 3),
        TaskDictionaryEntry(name: "Plant Seeds", emoji: "🌻", frequencyLabel: "Quarterly", recurrence: .monthly, suggestedReward: 8),
        TaskDictionaryEntry(name: "Clean Garage", emoji: "🏠", frequencyLabel: "Monthly", recurrence: .monthly, suggestedReward: 12),
    ]),
    TaskDictionaryCategory(name: "Car / Vehicle", icon: "car.fill", color: Color(red: 0.3, green: 0.3, blue: 0.8), tasks: [
        TaskDictionaryEntry(name: "Car Wash (Exterior)", emoji: "🚗", frequencyLabel: "Monthly", recurrence: .monthly, suggestedReward: 10),
        TaskDictionaryEntry(name: "Car Cleaning (Interior)", emoji: "🧽", frequencyLabel: "Monthly", recurrence: .monthly, suggestedReward: 8),
        TaskDictionaryEntry(name: "Check Tire Pressure", emoji: "🛞", frequencyLabel: "Monthly", recurrence: .monthly, suggestedReward: 3),
        TaskDictionaryEntry(name: "Oil Change", emoji: "🛢️", frequencyLabel: "Quarterly", recurrence: .monthly, suggestedReward: 5),
        TaskDictionaryEntry(name: "Refuel / Charge Vehicle", emoji: "⛽", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 3),
        TaskDictionaryEntry(name: "Vehicle Inspection", emoji: "🔍", frequencyLabel: "Annual", recurrence: .none, suggestedReward: 5),
        TaskDictionaryEntry(name: "Registration Renewal", emoji: "📋", frequencyLabel: "Annual", recurrence: .none, suggestedReward: 5),
        TaskDictionaryEntry(name: "Replace Wiper Blades", emoji: "🌧️", frequencyLabel: "Half-Yearly", recurrence: .none, suggestedReward: 5),
        TaskDictionaryEntry(name: "Organize Trunk", emoji: "📦", frequencyLabel: "Monthly", recurrence: .monthly, suggestedReward: 4),
    ]),
    TaskDictionaryCategory(name: "Pet Care", icon: "pawprint.fill", color: .brown, tasks: [
        TaskDictionaryEntry(name: "Feed Pet", emoji: "🐾", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 3),
        TaskDictionaryEntry(name: "Walk the Dog", emoji: "🐕", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 5),
        TaskDictionaryEntry(name: "Clean Litter Box", emoji: "🐈", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 4),
        TaskDictionaryEntry(name: "Refill Water Bowl", emoji: "💧", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 1),
        TaskDictionaryEntry(name: "Brush Pet", emoji: "🐾", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 4),
        TaskDictionaryEntry(name: "Give Pet a Bath", emoji: "🛁", frequencyLabel: "Monthly", recurrence: .monthly, suggestedReward: 8),
        TaskDictionaryEntry(name: "Clean Fish Tank", emoji: "🐟", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 5),
        TaskDictionaryEntry(name: "Vet Appointment", emoji: "🏥", frequencyLabel: "Annual", recurrence: .none, suggestedReward: 5),
    ]),
    TaskDictionaryCategory(name: "Health & Hygiene", icon: "heart.fill", color: .pink, tasks: [
        TaskDictionaryEntry(name: "Shower / Bath", emoji: "🚿", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 1),
        TaskDictionaryEntry(name: "Floss Teeth", emoji: "🦷", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 1),
        TaskDictionaryEntry(name: "Exercise / Workout", emoji: "💪", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 5),
        TaskDictionaryEntry(name: "Drink Enough Water", emoji: "💧", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 1),
        TaskDictionaryEntry(name: "Yoga", emoji: "🧘", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 3),
        TaskDictionaryEntry(name: "Stretching", emoji: "🤸", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 2),
        TaskDictionaryEntry(name: "Haircut Appointment", emoji: "💇", frequencyLabel: "Monthly", recurrence: .monthly, suggestedReward: 3),
        TaskDictionaryEntry(name: "Dentist Appointment", emoji: "🦷", frequencyLabel: "Half-Yearly", recurrence: .none, suggestedReward: 10),
        TaskDictionaryEntry(name: "Annual Health Check", emoji: "🩺", frequencyLabel: "Annual", recurrence: .none, suggestedReward: 10),
        TaskDictionaryEntry(name: "Eye Exam", emoji: "👁️", frequencyLabel: "Annual", recurrence: .none, suggestedReward: 5),
        TaskDictionaryEntry(name: "Bedtime Brushing", emoji: "🪥", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 1),
        TaskDictionaryEntry(name: "Early Bedtime", emoji: "😴", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 2),
        TaskDictionaryEntry(name: "Mind Detox", emoji: "🧠", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 3),
    ]),
    TaskDictionaryCategory(name: "Music & Arts", icon: "music.note", color: .purple, tasks: [
        TaskDictionaryEntry(name: "Practice Piano", emoji: "🎹", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 5),
        TaskDictionaryEntry(name: "Practice Guitar", emoji: "🎸", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 5),
        TaskDictionaryEntry(name: "Practice Violin", emoji: "🎻", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 5),
        TaskDictionaryEntry(name: "Practice Drums", emoji: "🥁", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 5),
        TaskDictionaryEntry(name: "Music Lesson", emoji: "🎵", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 5),
        TaskDictionaryEntry(name: "Art Class", emoji: "🎨", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 5),
        TaskDictionaryEntry(name: "Drawing Practice", emoji: "✏️", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 3),
        TaskDictionaryEntry(name: "Craft Project", emoji: "✂️", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 6),
        TaskDictionaryEntry(name: "Singing Practice", emoji: "🎤", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 3),
        TaskDictionaryEntry(name: "Coloring / Painting", emoji: "🖌️", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 3),
    ]),
    TaskDictionaryCategory(name: "Sports & Fitness", icon: "figure.run", color: .cyan, tasks: [
        TaskDictionaryEntry(name: "Soccer Practice", emoji: "⚽", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 5),
        TaskDictionaryEntry(name: "Basketball Practice", emoji: "🏀", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 5),
        TaskDictionaryEntry(name: "Swimming Lesson", emoji: "🏊", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 5),
        TaskDictionaryEntry(name: "Bike Ride", emoji: "🚲", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 4),
        TaskDictionaryEntry(name: "Go for a Run", emoji: "🏃", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 5),
        TaskDictionaryEntry(name: "Tennis Practice", emoji: "🎾", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 5),
        TaskDictionaryEntry(name: "Dance Class", emoji: "💃", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 5),
        TaskDictionaryEntry(name: "Gymnastics", emoji: "🤸", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 5),
        TaskDictionaryEntry(name: "Martial Arts", emoji: "🥋", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 5),
        TaskDictionaryEntry(name: "Go to the Playground", emoji: "🛝", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 2),
    ]),
    TaskDictionaryCategory(name: "Social & Family", icon: "person.2.fill", color: .indigo, tasks: [
        TaskDictionaryEntry(name: "Call Grandparents", emoji: "📞", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 3),
        TaskDictionaryEntry(name: "Write Thank-You Card", emoji: "💌", frequencyLabel: "Monthly", recurrence: .monthly, suggestedReward: 5),
        TaskDictionaryEntry(name: "Help a Sibling", emoji: "🤝", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 3),
        TaskDictionaryEntry(name: "Family Game Night", emoji: "🎲", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 3),
        TaskDictionaryEntry(name: "Volunteer / Community Service", emoji: "🤲", frequencyLabel: "Monthly", recurrence: .monthly, suggestedReward: 15),
        TaskDictionaryEntry(name: "Play with Younger Sibling", emoji: "👫", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 3),
        TaskDictionaryEntry(name: "Visit a Friend", emoji: "🏠", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 2),
        TaskDictionaryEntry(name: "Birthday Card for Friend", emoji: "🎂", frequencyLabel: "Monthly", recurrence: .none, suggestedReward: 3),
    ]),
    TaskDictionaryCategory(name: "Money & Savings", icon: "dollarsign.circle.fill", color: .yellow, tasks: [
        TaskDictionaryEntry(name: "Save Allowance", emoji: "💰", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 2),
        TaskDictionaryEntry(name: "Track Spending", emoji: "📊", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 3),
        TaskDictionaryEntry(name: "Piggy Bank Deposit", emoji: "🐷", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 2),
        TaskDictionaryEntry(name: "Garage Sale Prep", emoji: "🏷️", frequencyLabel: "Quarterly", recurrence: .monthly, suggestedReward: 10),
        TaskDictionaryEntry(name: "Lemonade Stand", emoji: "🍋", frequencyLabel: "Monthly", recurrence: .none, suggestedReward: 10),
    ]),
    TaskDictionaryCategory(name: "Safety & Life Skills", icon: "shield.fill", color: .teal, tasks: [
        TaskDictionaryEntry(name: "Practice Fire Drill", emoji: "🧯", frequencyLabel: "Quarterly", recurrence: .monthly, suggestedReward: 5),
        TaskDictionaryEntry(name: "Learn to Cook a Meal", emoji: "👨‍🍳", frequencyLabel: "Monthly", recurrence: .monthly, suggestedReward: 10),
        TaskDictionaryEntry(name: "Learn First Aid", emoji: "🩹", frequencyLabel: "Half-Yearly", recurrence: .none, suggestedReward: 8),
        TaskDictionaryEntry(name: "Sew a Button", emoji: "🧵", frequencyLabel: "Monthly", recurrence: .none, suggestedReward: 5),
        TaskDictionaryEntry(name: "Sort Recycling", emoji: "♻️", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 3),
        TaskDictionaryEntry(name: "Check Smoke Detectors", emoji: "🔔", frequencyLabel: "Half-Yearly", recurrence: .none, suggestedReward: 5),
    ]),
    TaskDictionaryCategory(name: "Seasonal & Special", icon: "calendar.badge.clock", color: Color(red: 0.8, green: 0.4, blue: 0.2), tasks: [
        TaskDictionaryEntry(name: "Spring Cleaning", emoji: "🧹", frequencyLabel: "Annual", recurrence: .none, suggestedReward: 20),
        TaskDictionaryEntry(name: "Back to School Prep", emoji: "🎒", frequencyLabel: "Annual", recurrence: .none, suggestedReward: 10),
        TaskDictionaryEntry(name: "Holiday Decorating", emoji: "🎄", frequencyLabel: "Annual", recurrence: .none, suggestedReward: 10),
        TaskDictionaryEntry(name: "Summer Reading Challenge", emoji: "📚", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 5),
        TaskDictionaryEntry(name: "Birthday Planning", emoji: "🎂", frequencyLabel: "Annual", recurrence: .none, suggestedReward: 5),
        TaskDictionaryEntry(name: "Holiday Cards", emoji: "✉️", frequencyLabel: "Annual", recurrence: .none, suggestedReward: 5),
        TaskDictionaryEntry(name: "School Supplies Shopping", emoji: "📎", frequencyLabel: "Annual", recurrence: .none, suggestedReward: 5),
        TaskDictionaryEntry(name: "Costume Prep", emoji: "🎭", frequencyLabel: "Annual", recurrence: .none, suggestedReward: 5),
    ]),
    TaskDictionaryCategory(name: "Technology & Screen", icon: "desktopcomputer", color: .gray, tasks: [
        TaskDictionaryEntry(name: "Limit Screen Time", emoji: "📱", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 3),
        TaskDictionaryEntry(name: "Back Up Homework Files", emoji: "💻", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 2),
        TaskDictionaryEntry(name: "Clean Up Email", emoji: "📧", frequencyLabel: "Monthly", recurrence: .monthly, suggestedReward: 3),
        TaskDictionaryEntry(name: "Organize Photos", emoji: "📸", frequencyLabel: "Monthly", recurrence: .monthly, suggestedReward: 3),
        TaskDictionaryEntry(name: "Learn a Coding Lesson", emoji: "💻", frequencyLabel: "Weekly", recurrence: .weekly, suggestedReward: 8),
        TaskDictionaryEntry(name: "No-Screen Hour", emoji: "🚫", frequencyLabel: "Daily", recurrence: .daily, suggestedReward: 3),
    ]),
]

// MARK: - Avatars

// MARK: - Avatar System

struct AvatarConfig: Equatable {
    let id: String
    let skinColor: Color
    let hairColor: Color
    let hairStyle: HairStyle
    let accessory: Accessory
    let bgColor: Color

    enum HairStyle: String {
        case short, long, curly, bun, pigtails, spiky, bald, bob
    }
    enum Accessory: String {
        case none, glasses, sunglasses, hat, beanie, bow
    }
}

let avatarPresets: [AvatarConfig] = [
    AvatarConfig(id: "av01", skinColor: Color(red: 1.0, green: 0.87, blue: 0.75), hairColor: .brown, hairStyle: .pigtails, accessory: .bow, bgColor: .pink),
    AvatarConfig(id: "av02", skinColor: Color(red: 0.76, green: 0.58, blue: 0.42), hairColor: Color(red: 0.15, green: 0.1, blue: 0.05), hairStyle: .short, accessory: .none, bgColor: .cyan),
    AvatarConfig(id: "av03", skinColor: Color(red: 0.55, green: 0.36, blue: 0.24), hairColor: Color(red: 0.1, green: 0.05, blue: 0.0), hairStyle: .curly, accessory: .none, bgColor: .purple),
    AvatarConfig(id: "av04", skinColor: Color(red: 1.0, green: 0.90, blue: 0.80), hairColor: Color(red: 0.9, green: 0.75, blue: 0.4), hairStyle: .short, accessory: .glasses, bgColor: .green),
    AvatarConfig(id: "av05", skinColor: Color(red: 0.85, green: 0.70, blue: 0.55), hairColor: Color(red: 0.7, green: 0.2, blue: 0.1), hairStyle: .long, accessory: .glasses, bgColor: .orange),
    AvatarConfig(id: "av06", skinColor: Color(red: 0.45, green: 0.30, blue: 0.20), hairColor: Color(red: 0.1, green: 0.05, blue: 0.0), hairStyle: .short, accessory: .hat, bgColor: .yellow),
    AvatarConfig(id: "av07", skinColor: Color(red: 1.0, green: 0.87, blue: 0.75), hairColor: Color(red: 0.15, green: 0.1, blue: 0.05), hairStyle: .bun, accessory: .none, bgColor: .indigo),
    AvatarConfig(id: "av08", skinColor: Color(red: 0.76, green: 0.58, blue: 0.42), hairColor: .brown, hairStyle: .spiky, accessory: .sunglasses, bgColor: .red),
    AvatarConfig(id: "av09", skinColor: Color(red: 1.0, green: 0.90, blue: 0.80), hairColor: Color(red: 0.78, green: 0.78, blue: 0.80), hairStyle: .bob, accessory: .none, bgColor: .teal),
    AvatarConfig(id: "av10", skinColor: Color(red: 0.55, green: 0.36, blue: 0.24), hairColor: Color(red: 0.7, green: 0.7, blue: 0.72), hairStyle: .short, accessory: .glasses, bgColor: .mint),
    AvatarConfig(id: "av11", skinColor: Color(red: 0.45, green: 0.30, blue: 0.20), hairColor: Color(red: 0.1, green: 0.05, blue: 0.0), hairStyle: .long, accessory: .beanie, bgColor: Color(red: 0.9, green: 0.5, blue: 0.6)),
    AvatarConfig(id: "av12", skinColor: Color(red: 1.0, green: 0.87, blue: 0.75), hairColor: Color(red: 0.8, green: 0.3, blue: 0.1), hairStyle: .spiky, accessory: .none, bgColor: .orange),
]

struct AnimalAvatarConfig: Equatable {
    let id: String
    let animal: AnimalType
    let bgColor: Color
    let animalColor: Color
    let accentColor: Color

    enum AnimalType: String {
        case cat, dog, bear, bunny, fox, panda, owl, frog, bird, fish, penguin, lion
    }
}

let animalAvatarPresets: [AnimalAvatarConfig] = [
    AnimalAvatarConfig(id: "an01", animal: .cat, bgColor: .orange, animalColor: Color(red: 1.0, green: 0.7, blue: 0.3), accentColor: Color(red: 1.0, green: 0.85, blue: 0.5)),
    AnimalAvatarConfig(id: "an02", animal: .dog, bgColor: .brown, animalColor: Color(red: 0.72, green: 0.53, blue: 0.35), accentColor: Color(red: 0.9, green: 0.8, blue: 0.65)),
    AnimalAvatarConfig(id: "an03", animal: .bear, bgColor: Color(red: 0.55, green: 0.35, blue: 0.2), animalColor: Color(red: 0.6, green: 0.4, blue: 0.25), accentColor: Color(red: 0.8, green: 0.65, blue: 0.5)),
    AnimalAvatarConfig(id: "an04", animal: .bunny, bgColor: .pink, animalColor: Color(red: 0.95, green: 0.9, blue: 0.9), accentColor: Color(red: 1.0, green: 0.7, blue: 0.75)),
    AnimalAvatarConfig(id: "an05", animal: .fox, bgColor: Color(red: 0.9, green: 0.4, blue: 0.1), animalColor: Color(red: 0.95, green: 0.55, blue: 0.15), accentColor: .white),
    AnimalAvatarConfig(id: "an06", animal: .panda, bgColor: .mint, animalColor: .white, accentColor: Color(red: 0.15, green: 0.15, blue: 0.15)),
    AnimalAvatarConfig(id: "an07", animal: .owl, bgColor: .indigo, animalColor: Color(red: 0.55, green: 0.4, blue: 0.3), accentColor: Color(red: 0.95, green: 0.85, blue: 0.6)),
    AnimalAvatarConfig(id: "an08", animal: .frog, bgColor: .green, animalColor: Color(red: 0.4, green: 0.75, blue: 0.3), accentColor: Color(red: 0.5, green: 0.85, blue: 0.4)),
    AnimalAvatarConfig(id: "an09", animal: .bird, bgColor: .cyan, animalColor: Color(red: 1.0, green: 0.85, blue: 0.2), accentColor: Color(red: 1.0, green: 0.5, blue: 0.1)),
    AnimalAvatarConfig(id: "an10", animal: .fish, bgColor: Color(red: 0.1, green: 0.4, blue: 0.7), animalColor: Color(red: 0.3, green: 0.7, blue: 0.5), accentColor: Color(red: 0.4, green: 0.85, blue: 0.65)),
    AnimalAvatarConfig(id: "an11", animal: .penguin, bgColor: Color(red: 0.6, green: 0.8, blue: 0.95), animalColor: Color(red: 0.15, green: 0.15, blue: 0.2), accentColor: .white),
    AnimalAvatarConfig(id: "an12", animal: .lion, bgColor: Color(red: 0.85, green: 0.6, blue: 0.15), animalColor: Color(red: 0.9, green: 0.7, blue: 0.35), accentColor: Color(red: 0.75, green: 0.45, blue: 0.1)),
]

let avatarOptions = avatarPresets.map { $0.id } + animalAvatarPresets.map { $0.id }

func avatarConfig(for id: String) -> AvatarConfig? {
    avatarPresets.first { $0.id == id }
}

func animalAvatarConfig(for id: String) -> AnimalAvatarConfig? {
    animalAvatarPresets.first { $0.id == id }
}

struct AvatarFaceView: View {
    let config: AvatarConfig
    let size: CGFloat

    private var faceSize: CGFloat { size * 0.6 }
    private var eyeSize: CGFloat { size * 0.055 }
    private var mouthWidth: CGFloat { size * 0.18 }

    var body: some View {
        ZStack {
            Circle()
                .fill(config.bgColor.opacity(0.3))
                .frame(width: size, height: size)

            Circle()
                .fill(config.skinColor)
                .frame(width: faceSize, height: faceSize)

            hairView
            eyesView
            mouthView
            accessoryView
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    @ViewBuilder
    private var hairView: some View {
        let hairY = -size * 0.2
        switch config.hairStyle {
        case .short:
            Ellipse()
                .fill(config.hairColor)
                .frame(width: faceSize * 0.85, height: faceSize * 0.4)
                .offset(y: hairY)
        case .long:
            VStack(spacing: 0) {
                Ellipse()
                    .fill(config.hairColor)
                    .frame(width: faceSize * 0.9, height: faceSize * 0.4)
                HStack(spacing: faceSize * 0.45) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(config.hairColor)
                        .frame(width: faceSize * 0.18, height: faceSize * 0.45)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(config.hairColor)
                        .frame(width: faceSize * 0.18, height: faceSize * 0.45)
                }
            }
            .offset(y: hairY)
        case .curly:
            ZStack {
                ForEach(0..<5, id: \.self) { i in
                    Circle()
                        .fill(config.hairColor)
                        .frame(width: faceSize * 0.28, height: faceSize * 0.28)
                        .offset(
                            x: cos(Double(i) * .pi / 2.5) * faceSize * 0.3,
                            y: hairY + sin(Double(i) * .pi / 2.5 - .pi) * faceSize * 0.15
                        )
                }
            }
        case .bun:
            VStack(spacing: -faceSize * 0.05) {
                Circle()
                    .fill(config.hairColor)
                    .frame(width: faceSize * 0.3, height: faceSize * 0.3)
                Ellipse()
                    .fill(config.hairColor)
                    .frame(width: faceSize * 0.85, height: faceSize * 0.35)
            }
            .offset(y: hairY - faceSize * 0.05)
        case .pigtails:
            ZStack {
                Ellipse()
                    .fill(config.hairColor)
                    .frame(width: faceSize * 0.85, height: faceSize * 0.35)
                    .offset(y: hairY)
                Circle()
                    .fill(config.hairColor)
                    .frame(width: faceSize * 0.22, height: faceSize * 0.22)
                    .offset(x: -faceSize * 0.38, y: hairY + faceSize * 0.08)
                Circle()
                    .fill(config.hairColor)
                    .frame(width: faceSize * 0.22, height: faceSize * 0.22)
                    .offset(x: faceSize * 0.38, y: hairY + faceSize * 0.08)
            }
        case .spiky:
            HStack(spacing: faceSize * 0.03) {
                ForEach(0..<5, id: \.self) { _ in
                    Triangle()
                        .fill(config.hairColor)
                        .frame(width: faceSize * 0.14, height: faceSize * 0.25)
                }
            }
            .offset(y: hairY - faceSize * 0.02)
        case .bald:
            EmptyView()
        case .bob:
            Ellipse()
                .fill(config.hairColor)
                .frame(width: faceSize * 0.95, height: faceSize * 0.5)
                .offset(y: hairY + faceSize * 0.02)
        }
    }

    @ViewBuilder
    private var eyesView: some View {
        let eyeY = -size * 0.02
        let eyeSpacing = size * 0.09
        HStack(spacing: eyeSpacing) {
            Circle().fill(.white).frame(width: eyeSize * 1.8, height: eyeSize * 1.8)
                .overlay(Circle().fill(Color(red: 0.2, green: 0.15, blue: 0.1)).frame(width: eyeSize, height: eyeSize))
            Circle().fill(.white).frame(width: eyeSize * 1.8, height: eyeSize * 1.8)
                .overlay(Circle().fill(Color(red: 0.2, green: 0.15, blue: 0.1)).frame(width: eyeSize, height: eyeSize))
        }
        .offset(y: eyeY)
    }

    private var mouthView: some View {
        SmileShape()
            .stroke(Color(red: 0.6, green: 0.2, blue: 0.15), lineWidth: size * 0.02)
            .frame(width: mouthWidth, height: mouthWidth * 0.4)
            .offset(y: size * 0.1)
    }

    @ViewBuilder
    private var accessoryView: some View {
        let eyeY = -size * 0.02
        switch config.accessory {
        case .glasses:
            HStack(spacing: size * 0.02) {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color(red: 0.3, green: 0.2, blue: 0.15), lineWidth: size * 0.015)
                    .frame(width: size * 0.12, height: size * 0.09)
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color(red: 0.3, green: 0.2, blue: 0.15), lineWidth: size * 0.015)
                    .frame(width: size * 0.12, height: size * 0.09)
            }
            .offset(y: eyeY)
        case .sunglasses:
            HStack(spacing: size * 0.02) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(red: 0.15, green: 0.1, blue: 0.1))
                    .frame(width: size * 0.13, height: size * 0.09)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(red: 0.15, green: 0.1, blue: 0.1))
                    .frame(width: size * 0.13, height: size * 0.09)
            }
            .offset(y: eyeY)
        case .hat:
            VStack(spacing: -size * 0.01) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.red)
                    .frame(width: faceSize * 0.5, height: faceSize * 0.35)
                RoundedRectangle(cornerRadius: 2)
                    .fill(.red.opacity(0.8))
                    .frame(width: faceSize * 0.8, height: faceSize * 0.08)
            }
            .offset(y: -size * 0.28)
        case .beanie:
            Capsule()
                .fill(Color(red: 0.3, green: 0.5, blue: 0.7))
                .frame(width: faceSize * 0.75, height: faceSize * 0.3)
                .offset(y: -size * 0.24)
        case .bow:
            HStack(spacing: 0) {
                Ellipse().fill(.red).frame(width: size * 0.06, height: size * 0.045)
                Circle().fill(.red.opacity(0.8)).frame(width: size * 0.025)
                Ellipse().fill(.red).frame(width: size * 0.06, height: size * 0.045)
            }
            .offset(x: faceSize * 0.25, y: -size * 0.2)
        case .none:
            EmptyView()
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY * 0.5))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY * 0.5),
            control: CGPoint(x: rect.midX, y: rect.maxY * 1.2)
        )
        return path
    }
}

struct AnimalAvatarFaceView: View {
    let config: AnimalAvatarConfig
    let size: CGFloat

    private var faceSize: CGFloat { size * 0.6 }
    private var eyeSize: CGFloat { size * 0.055 }

    var body: some View {
        ZStack {
            Circle()
                .fill(config.bgColor.opacity(0.3))
                .frame(width: size, height: size)

            Circle()
                .fill(config.animalColor)
                .frame(width: faceSize, height: faceSize)

            earsView
            eyesView
            noseView
            mouthView
            markingsView
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    @ViewBuilder
    private var earsView: some View {
        switch config.animal {
        case .cat, .fox:
            HStack(spacing: faceSize * 0.5) {
                Triangle()
                    .fill(config.animalColor)
                    .frame(width: faceSize * 0.3, height: faceSize * 0.35)
                    .overlay(
                        Triangle()
                            .fill(config.accentColor.opacity(0.6))
                            .frame(width: faceSize * 0.15, height: faceSize * 0.18)
                            .offset(y: faceSize * 0.05)
                    )
                Triangle()
                    .fill(config.animalColor)
                    .frame(width: faceSize * 0.3, height: faceSize * 0.35)
                    .overlay(
                        Triangle()
                            .fill(config.accentColor.opacity(0.6))
                            .frame(width: faceSize * 0.15, height: faceSize * 0.18)
                            .offset(y: faceSize * 0.05)
                    )
            }
            .offset(y: -size * 0.24)
        case .dog:
            HStack(spacing: faceSize * 0.55) {
                Ellipse()
                    .fill(config.accentColor)
                    .frame(width: faceSize * 0.28, height: faceSize * 0.35)
                    .rotationEffect(.degrees(-20))
                Ellipse()
                    .fill(config.accentColor)
                    .frame(width: faceSize * 0.28, height: faceSize * 0.35)
                    .rotationEffect(.degrees(20))
            }
            .offset(y: -size * 0.2)
        case .bear:
            HStack(spacing: faceSize * 0.52) {
                Circle()
                    .fill(config.animalColor)
                    .frame(width: faceSize * 0.28, height: faceSize * 0.28)
                    .overlay(Circle().fill(config.accentColor).frame(width: faceSize * 0.15))
                Circle()
                    .fill(config.animalColor)
                    .frame(width: faceSize * 0.28, height: faceSize * 0.28)
                    .overlay(Circle().fill(config.accentColor).frame(width: faceSize * 0.15))
            }
            .offset(y: -size * 0.22)
        case .bunny:
            HStack(spacing: faceSize * 0.15) {
                Capsule()
                    .fill(config.animalColor)
                    .frame(width: faceSize * 0.2, height: faceSize * 0.55)
                    .overlay(Capsule().fill(config.accentColor).frame(width: faceSize * 0.1, height: faceSize * 0.35))
                    .rotationEffect(.degrees(-8))
                Capsule()
                    .fill(config.animalColor)
                    .frame(width: faceSize * 0.2, height: faceSize * 0.55)
                    .overlay(Capsule().fill(config.accentColor).frame(width: faceSize * 0.1, height: faceSize * 0.35))
                    .rotationEffect(.degrees(8))
            }
            .offset(y: -size * 0.3)
        case .panda:
            HStack(spacing: faceSize * 0.52) {
                Circle()
                    .fill(config.accentColor)
                    .frame(width: faceSize * 0.26, height: faceSize * 0.26)
                Circle()
                    .fill(config.accentColor)
                    .frame(width: faceSize * 0.26, height: faceSize * 0.26)
            }
            .offset(y: -size * 0.22)
        case .owl:
            HStack(spacing: faceSize * 0.45) {
                Triangle()
                    .fill(config.animalColor)
                    .frame(width: faceSize * 0.22, height: faceSize * 0.25)
                Triangle()
                    .fill(config.animalColor)
                    .frame(width: faceSize * 0.22, height: faceSize * 0.25)
            }
            .offset(y: -size * 0.24)
        case .frog:
            HStack(spacing: faceSize * 0.4) {
                Circle()
                    .fill(config.animalColor)
                    .frame(width: faceSize * 0.25, height: faceSize * 0.25)
                    .overlay(Circle().fill(.white).frame(width: faceSize * 0.16).overlay(Circle().fill(Color(red: 0.2, green: 0.15, blue: 0.1)).frame(width: faceSize * 0.08)))
                Circle()
                    .fill(config.animalColor)
                    .frame(width: faceSize * 0.25, height: faceSize * 0.25)
                    .overlay(Circle().fill(.white).frame(width: faceSize * 0.16).overlay(Circle().fill(Color(red: 0.2, green: 0.15, blue: 0.1)).frame(width: faceSize * 0.08)))
            }
            .offset(y: -size * 0.22)
        case .bird:
            // small tuft/crest on top
            ZStack {
                Ellipse()
                    .fill(config.accentColor)
                    .frame(width: faceSize * 0.18, height: faceSize * 0.3)
                    .rotationEffect(.degrees(-10))
                    .offset(x: -faceSize * 0.05)
                Ellipse()
                    .fill(config.accentColor)
                    .frame(width: faceSize * 0.15, height: faceSize * 0.25)
                    .rotationEffect(.degrees(15))
                    .offset(x: faceSize * 0.08)
            }
            .offset(y: -size * 0.28)
        case .fish:
            // tail fin
            HStack(spacing: 0) {
                Spacer()
                Triangle()
                    .fill(config.accentColor)
                    .frame(width: faceSize * 0.35, height: faceSize * 0.4)
                    .rotationEffect(.degrees(90))
            }
            .frame(width: size * 0.45)
            .offset(x: size * 0.22, y: 0)
        case .penguin:
            EmptyView()
        case .lion:
            // mane - ring of circles
            ZStack {
                ForEach(0..<8, id: \.self) { i in
                    Circle()
                        .fill(config.accentColor)
                        .frame(width: faceSize * 0.28, height: faceSize * 0.28)
                        .offset(
                            x: cos(Double(i) * .pi / 4) * faceSize * 0.38,
                            y: sin(Double(i) * .pi / 4) * faceSize * 0.38
                        )
                }
            }
        }
    }

    @ViewBuilder
    private var eyesView: some View {
        if config.animal == .frog { EmptyView() }
        else if config.animal == .fish {
            // single visible eye (side profile feel)
            Circle().fill(.white).frame(width: eyeSize * 2, height: eyeSize * 2)
                .overlay(Circle().fill(Color(red: 0.1, green: 0.1, blue: 0.15)).frame(width: eyeSize * 1.1))
                .offset(x: -size * 0.04, y: -size * 0.02)
        } else if config.animal == .penguin {
            HStack(spacing: size * 0.06) {
                Circle().fill(.white).frame(width: eyeSize * 2.4, height: eyeSize * 2.4)
                    .overlay(Circle().fill(Color(red: 0.1, green: 0.1, blue: 0.15)).frame(width: eyeSize * 1.1))
                Circle().fill(.white).frame(width: eyeSize * 2.4, height: eyeSize * 2.4)
                    .overlay(Circle().fill(Color(red: 0.1, green: 0.1, blue: 0.15)).frame(width: eyeSize * 1.1))
            }
            .offset(y: -size * 0.03)
        } else if config.animal == .panda {
            HStack(spacing: size * 0.06) {
                Circle().fill(config.accentColor).frame(width: eyeSize * 2.8, height: eyeSize * 2.8)
                    .overlay(Circle().fill(.white).frame(width: eyeSize * 1.8).overlay(Circle().fill(Color(red: 0.2, green: 0.15, blue: 0.1)).frame(width: eyeSize)))
                Circle().fill(config.accentColor).frame(width: eyeSize * 2.8, height: eyeSize * 2.8)
                    .overlay(Circle().fill(.white).frame(width: eyeSize * 1.8).overlay(Circle().fill(Color(red: 0.2, green: 0.15, blue: 0.1)).frame(width: eyeSize)))
            }
            .offset(y: -size * 0.03)
        } else if config.animal == .owl {
            HStack(spacing: size * 0.04) {
                Circle().fill(config.accentColor).frame(width: eyeSize * 3.2, height: eyeSize * 3.2)
                    .overlay(Circle().fill(.white).frame(width: eyeSize * 2).overlay(Circle().fill(Color(red: 0.2, green: 0.15, blue: 0.1)).frame(width: eyeSize * 1.1)))
                Circle().fill(config.accentColor).frame(width: eyeSize * 3.2, height: eyeSize * 3.2)
                    .overlay(Circle().fill(.white).frame(width: eyeSize * 2).overlay(Circle().fill(Color(red: 0.2, green: 0.15, blue: 0.1)).frame(width: eyeSize * 1.1)))
            }
            .offset(y: -size * 0.03)
        } else {
            HStack(spacing: size * 0.09) {
                Circle().fill(.white).frame(width: eyeSize * 1.8, height: eyeSize * 1.8)
                    .overlay(Circle().fill(Color(red: 0.2, green: 0.15, blue: 0.1)).frame(width: eyeSize))
                Circle().fill(.white).frame(width: eyeSize * 1.8, height: eyeSize * 1.8)
                    .overlay(Circle().fill(Color(red: 0.2, green: 0.15, blue: 0.1)).frame(width: eyeSize))
            }
            .offset(y: -size * 0.02)
        }
    }

    @ViewBuilder
    private var noseView: some View {
        switch config.animal {
        case .cat, .fox:
            Triangle()
                .fill(config.animal == .fox ? Color(red: 0.15, green: 0.15, blue: 0.15) : .pink)
                .frame(width: size * 0.06, height: size * 0.04)
                .rotationEffect(.degrees(180))
                .offset(y: size * 0.06)
        case .dog, .bear:
            Ellipse()
                .fill(Color(red: 0.15, green: 0.12, blue: 0.1))
                .frame(width: size * 0.08, height: size * 0.05)
                .offset(y: size * 0.06)
        case .bunny:
            Ellipse()
                .fill(.pink)
                .frame(width: size * 0.06, height: size * 0.04)
                .offset(y: size * 0.06)
        case .panda:
            Ellipse()
                .fill(config.accentColor)
                .frame(width: size * 0.07, height: size * 0.04)
                .offset(y: size * 0.06)
        case .owl:
            Triangle()
                .fill(config.accentColor)
                .frame(width: size * 0.07, height: size * 0.05)
                .rotationEffect(.degrees(180))
                .offset(y: size * 0.07)
        case .frog:
            EmptyView()
        case .bird:
            // beak
            Triangle()
                .fill(config.accentColor)
                .frame(width: size * 0.1, height: size * 0.08)
                .rotationEffect(.degrees(180))
                .offset(y: size * 0.06)
        case .fish:
            // fish lips
            Ellipse()
                .fill(config.accentColor.opacity(0.7))
                .frame(width: size * 0.06, height: size * 0.04)
                .offset(x: -size * 0.15, y: size * 0.04)
        case .penguin:
            // beak
            Triangle()
                .fill(Color(red: 1.0, green: 0.6, blue: 0.1))
                .frame(width: size * 0.09, height: size * 0.07)
                .rotationEffect(.degrees(180))
                .offset(y: size * 0.06)
        case .lion:
            Ellipse()
                .fill(Color(red: 0.2, green: 0.12, blue: 0.08))
                .frame(width: size * 0.07, height: size * 0.045)
                .offset(y: size * 0.06)
        }
    }

    @ViewBuilder
    private var mouthView: some View {
        if config.animal == .frog {
            SmileShape()
                .stroke(Color(red: 0.25, green: 0.5, blue: 0.2), lineWidth: size * 0.02)
                .frame(width: size * 0.25, height: size * 0.08)
                .offset(y: size * 0.1)
        } else if config.animal == .cat || config.animal == .fox || config.animal == .bird || config.animal == .fish || config.animal == .penguin {
            EmptyView()
        } else {
            SmileShape()
                .stroke(Color(red: 0.3, green: 0.2, blue: 0.15), lineWidth: size * 0.015)
                .frame(width: size * 0.12, height: size * 0.05)
                .offset(y: size * 0.1)
        }
    }

    @ViewBuilder
    private var markingsView: some View {
        switch config.animal {
        case .cat:
            // whiskers
            HStack(spacing: faceSize * 0.35) {
                VStack(spacing: size * 0.02) {
                    Capsule().fill(Color.gray.opacity(0.4)).frame(width: size * 0.12, height: size * 0.01).rotationEffect(.degrees(-5))
                    Capsule().fill(Color.gray.opacity(0.4)).frame(width: size * 0.12, height: size * 0.01).rotationEffect(.degrees(5))
                }
                VStack(spacing: size * 0.02) {
                    Capsule().fill(Color.gray.opacity(0.4)).frame(width: size * 0.12, height: size * 0.01).rotationEffect(.degrees(5))
                    Capsule().fill(Color.gray.opacity(0.4)).frame(width: size * 0.12, height: size * 0.01).rotationEffect(.degrees(-5))
                }
            }
            .offset(y: size * 0.06)
        case .fox:
            // white muzzle
            Ellipse()
                .fill(config.accentColor)
                .frame(width: faceSize * 0.45, height: faceSize * 0.35)
                .offset(y: size * 0.08)
        case .dog:
            // muzzle
            Ellipse()
                .fill(config.accentColor)
                .frame(width: faceSize * 0.4, height: faceSize * 0.3)
                .offset(y: size * 0.07)
        case .bear:
            // muzzle
            Ellipse()
                .fill(config.accentColor)
                .frame(width: faceSize * 0.38, height: faceSize * 0.28)
                .offset(y: size * 0.06)
        case .bunny:
            // cheeks
            HStack(spacing: faceSize * 0.3) {
                Circle().fill(.pink.opacity(0.3)).frame(width: size * 0.08)
                Circle().fill(.pink.opacity(0.3)).frame(width: size * 0.08)
            }
            .offset(y: size * 0.06)
        case .bird:
            // cheek blush
            HStack(spacing: faceSize * 0.3) {
                Circle().fill(config.accentColor.opacity(0.4)).frame(width: size * 0.07)
                Circle().fill(config.accentColor.opacity(0.4)).frame(width: size * 0.07)
            }
            .offset(y: size * 0.04)
        case .fish:
            // scales pattern
            HStack(spacing: size * 0.02) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(config.accentColor.opacity(0.3))
                        .frame(width: size * 0.05)
                }
            }
            .offset(x: size * 0.05, y: size * 0.05)
        case .penguin:
            // white belly
            Ellipse()
                .fill(config.accentColor)
                .frame(width: faceSize * 0.5, height: faceSize * 0.45)
                .offset(y: size * 0.08)
        case .lion:
            // muzzle
            Ellipse()
                .fill(config.accentColor.opacity(0.5))
                .frame(width: faceSize * 0.4, height: faceSize * 0.3)
                .offset(y: size * 0.06)
        default:
            EmptyView()
        }
    }
}

// MARK: - Avatar Photo Storage

func avatarPhotoDirectory() -> URL {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let dir = docs.appendingPathComponent("avatar_photos")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

func saveAvatarPhoto(_ image: UIImage, photoID: String) -> Bool {
    guard let data = image.jpegData(compressionQuality: 0.8) else { return false }
    let url = avatarPhotoDirectory().appendingPathComponent("\(photoID).jpg")
    do {
        try data.write(to: url)
        return true
    } catch {
        return false
    }
}

func loadAvatarPhoto(photoID: String) -> UIImage? {
    let url = avatarPhotoDirectory().appendingPathComponent("\(photoID).jpg")
    guard let data = try? Data(contentsOf: url) else { return nil }
    return UIImage(data: data)
}

func avatarPhotoURL(photoID: String) -> URL {
    avatarPhotoDirectory().appendingPathComponent("\(photoID).jpg")
}

struct AvatarView: View {
    let avatarId: String
    let size: CGFloat

    var body: some View {
        if avatarId.hasPrefix("photo_") {
            let photoID = String(avatarId.dropFirst(6))
            if let image = loadAvatarPhoto(photoID: photoID) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: size * 0.9))
                    .foregroundStyle(.primary.opacity(0.5))
                    .frame(width: size, height: size)
            }
        } else if let config = avatarConfig(for: avatarId) {
            AvatarFaceView(config: config, size: size)
        } else if let animalConfig = animalAvatarConfig(for: avatarId) {
            AnimalAvatarFaceView(config: animalConfig, size: size)
        } else {
            Image(systemName: "star.fill")
                .font(.system(size: size * 0.45))
                .foregroundStyle(avatarColor(for: avatarId))
                .frame(width: size, height: size)
                .background(avatarColor(for: avatarId).opacity(0.2), in: Circle())
        }
    }
}

// MARK: - Date Helpers

func roundedToNext5Minutes(_ date: Date = Date()) -> Date {
    let calendar = Calendar.current
    let minute = calendar.component(.minute, from: date)
    let remainder = minute % 5
    let roundUp = remainder == 0 ? 0 : 5 - remainder
    var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    comps.minute = minute + roundUp
    comps.second = 0
    return calendar.date(from: comps) ?? date
}

struct FiveMinuteDatePicker: UIViewRepresentable {
    @Binding var selection: Date
    var minimumDate: Date?

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .dateAndTime
        picker.preferredDatePickerStyle = .compact
        picker.minuteInterval = 5
        picker.minimumDate = minimumDate
        picker.date = selection
        picker.overrideUserInterfaceStyle = .dark
        picker.addTarget(context.coordinator, action: #selector(Coordinator.dateChanged(_:)), for: .valueChanged)
        return picker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        picker.date = selection
        picker.minimumDate = minimumDate
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    class Coordinator: NSObject {
        var selection: Binding<Date>
        init(selection: Binding<Date>) { self.selection = selection }
        @objc func dateChanged(_ picker: UIDatePicker) {
            selection.wrappedValue = picker.date
        }
    }
}

// MARK: - App Share

let appStoreURL = URL(string: "https://apps.apple.com/app/taskee/id0000000000")!
let parentShareMessage = "Hey! Taskoot has been a game-changer for our family — my kids actually WANT to do their chores now. They earn coins, redeem real rewards, and it's taught them so much about responsibility. Seriously the best parenting hack I've found. You've gotta try it!"

let childShareMessage = "Okay so my parents got this app called Taskoot and it's actually really fun?? You get coins every time you finish a task and you can save up for REAL rewards like toys or movie nights. It turns chores into a game — tell your parents to download it!"

let privacyPolicyURL = URL(string: "https://selvabhuvanesh.github.io/taskee/privacy")!
let termsOfUseURL = URL(string: "https://selvabhuvanesh.github.io/taskee/terms")!
let manageSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

class ShareTextWithLink: NSObject, UIActivityItemSource {
    let text: String
    let url: URL

    init(text: String, url: URL) {
        self.text = text
        self.url = url
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return text
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return "\(text)\n\n\(url.absoluteString)"
    }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return "Check out Taskoot!"
    }
}

// MARK: - Coin Display

struct CoinDisplay: View {
    let count: Int
    let earned: Bool

    private var coinGradient: LinearGradient {
        LinearGradient(
            colors: earned
                ? [Color(red: 1.0, green: 0.95, blue: 0.4), Color(red: 1.0, green: 0.7, blue: 0.0)]
                : [Color(red: 1.0, green: 0.95, blue: 0.4).opacity(0.8), Color(red: 1.0, green: 0.7, blue: 0.0).opacity(0.8)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var labelColor: Color {
        earned ? Color(red: 1.0, green: 0.84, blue: 0.0) : Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.8)
    }

    var body: some View {
        HStack(spacing: 3) {
            if earned {
                Text("Earned")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(labelColor)
            }
            Image(systemName: "star.circle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(coinGradient)
                .shadow(color: Color(red: 1.0, green: 0.7, blue: 0.0).opacity(0.4), radius: 2, y: 1)
            if count > 1 {
                Text("×\(count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(labelColor)
            }
        }
    }
}

// MARK: - Gift Reveal

struct GiftRevealView: View {
    let giftText: String
    var onDismiss: () -> Void

    @State private var phase = 0
    @State private var shakeAngle: Double = 0
    @State private var boxScale: Double = 1.0
    @State private var showConfetti = false
    @State private var textOpacity: Double = 0
    @State private var textScale: Double = 0.3
    @State private var glowOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    if phase >= 3 { onDismiss() }
                }

            if showConfetti {
                GiftConfettiView()
            }

            VStack(spacing: 24) {
                if phase < 3 {
                    ZStack {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 100))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.pink, .purple, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .pink.opacity(glowOpacity), radius: 20)
                            .rotationEffect(.degrees(shakeAngle))
                            .scaleEffect(boxScale)

                        if phase == 0 {
                            Text("Tap to open!")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.primary.opacity(0.8))
                                .offset(y: 70)
                        }
                    }
                    .onTapGesture { advancePhase() }
                }

                if phase >= 3 {
                    VStack(spacing: 16) {
                        Image(systemName: "gift.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.yellow)
                            .shadow(color: .yellow.opacity(0.5), radius: 10)

                        Text("Surprise Gift!")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)

                        Text(giftText)
                            .font(.title.weight(.heavy))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.yellow, .orange, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        Text("Tap anywhere to close")
                            .font(.caption)
                            .foregroundStyle(.primary.opacity(0.5))
                            .padding(.top, 8)
                    }
                    .scaleEffect(textScale)
                    .opacity(textOpacity)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                glowOpacity = 0.6
            }
        }
    }

    private func advancePhase() {
        switch phase {
        case 0:
            phase = 1
            withAnimation(.easeInOut(duration: 0.08).repeatCount(8, autoreverses: true)) {
                shakeAngle = 12
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                shakeAngle = 0
                advancePhase()
            }
        case 1:
            phase = 2
            withAnimation(.easeInOut(duration: 0.15).repeatCount(12, autoreverses: true)) {
                shakeAngle = 18
            }
            withAnimation(.easeInOut(duration: 0.5)) {
                boxScale = 1.2
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                advancePhase()
            }
        case 2:
            phase = 3
            SoundManager.shared.playApplause()
            showConfetti = true
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                boxScale = 0
                textOpacity = 1
                textScale = 1.0
            }
        default:
            break
        }
    }
}

struct GiftConfettiView: View {
    @State private var particles: [(id: Int, x: CGFloat, y: CGFloat, color: Color, size: CGFloat, rotation: Double)] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles, id: \.id) { p in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(p.color)
                        .frame(width: p.size, height: p.size * 1.5)
                        .rotationEffect(.degrees(p.rotation))
                        .position(x: p.x, y: p.y)
                }
            }
            .onAppear {
                let colors: [Color] = [.pink, .purple, .orange, .yellow, .cyan, .green, .red]
                for i in 0..<40 {
                    let startX = geo.size.width / 2 + CGFloat.random(in: -40...40)
                    particles.append((
                        id: i,
                        x: startX,
                        y: geo.size.height * 0.35,
                        color: colors.randomElement()!,
                        size: CGFloat.random(in: 6...12),
                        rotation: Double.random(in: 0...360)
                    ))
                }
                for i in 0..<40 {
                    let targetX = CGFloat.random(in: 20...(geo.size.width - 20))
                    let targetY = CGFloat.random(in: (geo.size.height * 0.5)...(geo.size.height - 40))
                    withAnimation(.easeOut(duration: Double.random(in: 0.8...1.5)).delay(Double(i) * 0.02)) {
                        particles[i].x = targetX
                        particles[i].y = targetY
                        particles[i].rotation += Double.random(in: 180...720)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Accent Color

let calmAccent = Color.blue

// MARK: - Child Theme

struct ThemePreset: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let gradientColors: [Color]
    var isLight: Bool = false
}

let themePresets: [ThemePreset] = [
    ThemePreset(id: "default", name: "Ocean", emoji: "🌊", gradientColors: [
        Color(red: 0.0, green: 0.5, blue: 0.5),
        Color(red: 0.15, green: 0.3, blue: 0.45),
        Color(red: 0.3, green: 0.1, blue: 0.4),
        Color(red: 0.35, green: 0.05, blue: 0.45)
    ]),
    ThemePreset(id: "sunset", name: "Sunset", emoji: "🌅", gradientColors: [
        Color(red: 0.95, green: 0.5, blue: 0.2),
        Color(red: 0.85, green: 0.25, blue: 0.3),
        Color(red: 0.55, green: 0.1, blue: 0.4),
        Color(red: 0.3, green: 0.05, blue: 0.35)
    ]),
    ThemePreset(id: "forest", name: "Forest", emoji: "🌲", gradientColors: [
        Color(red: 0.1, green: 0.5, blue: 0.3),
        Color(red: 0.05, green: 0.35, blue: 0.25),
        Color(red: 0.05, green: 0.25, blue: 0.2),
        Color(red: 0.05, green: 0.15, blue: 0.15)
    ]),
    ThemePreset(id: "galaxy", name: "Galaxy", emoji: "🌌", gradientColors: [
        Color(red: 0.1, green: 0.1, blue: 0.35),
        Color(red: 0.2, green: 0.05, blue: 0.4),
        Color(red: 0.35, green: 0.0, blue: 0.5),
        Color(red: 0.15, green: 0.0, blue: 0.25)
    ]),
    ThemePreset(id: "candy", name: "Candy", emoji: "🍬", gradientColors: [
        Color(red: 0.95, green: 0.4, blue: 0.6),
        Color(red: 0.7, green: 0.3, blue: 0.7),
        Color(red: 0.45, green: 0.2, blue: 0.6),
        Color(red: 0.3, green: 0.1, blue: 0.45)
    ]),
    ThemePreset(id: "midnight", name: "Midnight", emoji: "🌙", gradientColors: [
        Color(red: 0.1, green: 0.12, blue: 0.25),
        Color(red: 0.08, green: 0.08, blue: 0.2),
        Color(red: 0.05, green: 0.05, blue: 0.15),
        Color(red: 0.02, green: 0.02, blue: 0.1)
    ]),
    ThemePreset(id: "lava", name: "Lava", emoji: "🌋", gradientColors: [
        Color(red: 0.9, green: 0.3, blue: 0.1),
        Color(red: 0.7, green: 0.15, blue: 0.1),
        Color(red: 0.45, green: 0.08, blue: 0.12),
        Color(red: 0.25, green: 0.05, blue: 0.1)
    ]),
    ThemePreset(id: "arctic", name: "Arctic", emoji: "❄️", gradientColors: [
        Color(red: 0.6, green: 0.85, blue: 0.95),
        Color(red: 0.3, green: 0.6, blue: 0.8),
        Color(red: 0.15, green: 0.35, blue: 0.6),
        Color(red: 0.1, green: 0.2, blue: 0.4)
    ]),
    ThemePreset(id: "cream", name: "Cream", emoji: "☀️", gradientColors: [
        Color(red: 1.0, green: 0.97, blue: 0.92),
        Color(red: 0.98, green: 0.93, blue: 0.85),
        Color(red: 0.95, green: 0.88, blue: 0.78),
        Color(red: 0.92, green: 0.85, blue: 0.75)
    ], isLight: true),
    ThemePreset(id: "sky", name: "Sky", emoji: "🏖️", gradientColors: [
        Color(red: 0.85, green: 0.93, blue: 1.0),
        Color(red: 0.75, green: 0.88, blue: 0.98),
        Color(red: 0.65, green: 0.82, blue: 0.95),
        Color(red: 0.55, green: 0.75, blue: 0.92)
    ], isLight: true),
    ThemePreset(id: "mint", name: "Mint", emoji: "🍃", gradientColors: [
        Color(red: 0.88, green: 0.97, blue: 0.92),
        Color(red: 0.78, green: 0.93, blue: 0.85),
        Color(red: 0.68, green: 0.88, blue: 0.80),
        Color(red: 0.60, green: 0.83, blue: 0.75)
    ], isLight: true),
    ThemePreset(id: "blush", name: "Blush", emoji: "🌸", gradientColors: [
        Color(red: 1.0, green: 0.92, blue: 0.94),
        Color(red: 0.97, green: 0.85, blue: 0.88),
        Color(red: 0.93, green: 0.78, blue: 0.83),
        Color(red: 0.90, green: 0.72, blue: 0.78)
    ], isLight: true),
]

struct FontStylePreset: Identifiable {
    let id: String
    let name: String
    let fontName: String?
}

let fontStylePresets: [FontStylePreset] = [
    FontStylePreset(id: "default", name: "Default", fontName: nil),
    FontStylePreset(id: "rounded", name: "Rounded", fontName: ".AppleSystemUIFontRounded-Regular"),
    FontStylePreset(id: "serif", name: "Serif", fontName: "Georgia"),
    FontStylePreset(id: "mono", name: "Mono", fontName: "Menlo"),
    FontStylePreset(id: "handwritten", name: "Handwritten", fontName: "Noteworthy-Bold"),
]

struct ChildTheme {
    var themeId: String
    var fontId: String

    var gradientColors: [Color] {
        (themePresets.first { $0.id == themeId } ?? themePresets[0]).gradientColors
    }

    var isLight: Bool {
        (themePresets.first { $0.id == themeId } ?? themePresets[0]).isLight
    }

    var colorScheme: ColorScheme {
        isLight ? .light : .dark
    }

    var textColor: Color {
        isLight ? .black : .white
    }

    var secondaryTextColor: Color {
        isLight ? .black.opacity(0.6) : .white.opacity(0.6)
    }

    var tertiaryTextColor: Color {
        isLight ? .black.opacity(0.35) : .white.opacity(0.35)
    }

    var cardBackground: Color {
        isLight ? .black.opacity(0.08) : .white.opacity(0.12)
    }

    var cardBackgroundLight: Color {
        isLight ? .black.opacity(0.05) : .white.opacity(0.08)
    }

    var fontName: String? {
        fontStylePresets.first { $0.id == fontId }?.fontName
    }

    func font(_ style: Font) -> Font {
        guard let name = fontName else { return style }
        return .custom(name, size: fontBaseSize(for: style))
    }

    private func fontBaseSize(for style: Font) -> CGFloat {
        switch style {
        case .body: return 17
        case .subheadline: return 15
        case .caption: return 12
        case .caption2: return 11
        case .title2: return 22
        case .title3: return 20
        default: return 17
        }
    }

    var keyPrefix: String = "child"

    static func load(for role: String = "child") -> ChildTheme {
        ChildTheme(
            themeId: UserDefaults.standard.string(forKey: "\(role)ThemeId") ?? "default",
            fontId: UserDefaults.standard.string(forKey: "\(role)FontId") ?? "default",
            keyPrefix: role
        )
    }

    func save() {
        UserDefaults.standard.set(themeId, forKey: "\(keyPrefix)ThemeId")
        UserDefaults.standard.set(fontId, forKey: "\(keyPrefix)FontId")
    }
}

func avatarColor(for avatar: String) -> Color {
    if let config = avatarConfig(for: avatar) {
        return config.bgColor
    }
    if let animalConfig = animalAvatarConfig(for: avatar) {
        return animalConfig.bgColor
    }
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

// MARK: - Smart Scheduler Parser

struct ParsedTask {
    var name: String = ""
    var targetDate: Date = Date()
    var assignedTo: String = ""
    var reward: Int = 0
    var recurrence: RecurrenceType = .none
    var occurrences: Int = 1
    var hasDate: Bool = false
}

struct SmartTaskParser {
    let familyMembers: [String]

    func parse(_ input: String) -> ParsedTask {
        var result = ParsedTask()
        var remaining = input

        // 1. Extract reward (e.g. "5 coins", "10coins")
        if let range = remaining.range(of: #"\d+\s*coins?"#, options: .regularExpression) {
            let matched = String(remaining[range])
            let digits = matched.filter { $0.isNumber }
            result.reward = Int(digits) ?? 0
            remaining.removeSubrange(range)
        }

        // 2. Extract recurrence keywords
        let recurrenceMap: [(String, RecurrenceType)] = [
            ("every day", .daily), ("everyday", .daily), ("daily", .daily),
            ("every week", .weekly), ("weekly", .weekly),
            ("every month", .monthly), ("monthly", .monthly),
            ("every monday", .weekly), ("every tuesday", .weekly),
            ("every wednesday", .weekly), ("every thursday", .weekly),
            ("every friday", .weekly), ("every saturday", .weekly),
            ("every sunday", .weekly),
        ]

        let lowered = remaining.lowercased()
        for (pattern, recurrence) in recurrenceMap {
            if let range = lowered.range(of: pattern) {
                result.recurrence = recurrence
                let start = remaining.index(remaining.startIndex, offsetBy: lowered.distance(from: lowered.startIndex, to: range.lowerBound))
                let end = remaining.index(remaining.startIndex, offsetBy: lowered.distance(from: lowered.startIndex, to: range.upperBound))
                remaining.removeSubrange(start..<end)
                break
            }
        }

        // 3. Extract date/time using NSDataDetector
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        if let match = detector?.firstMatch(in: remaining, range: NSRange(remaining.startIndex..., in: remaining)),
           let date = match.date,
           let range = Range(match.range, in: remaining) {
            if date >= Calendar.current.startOfDay(for: Date()) {
                result.targetDate = date
                result.hasDate = true
            }
            remaining.removeSubrange(range)
        }

        // 4. Extract assignee (e.g. "for Arya", "assign to Arya")
        for member in familyMembers {
            let patterns = ["for \(member)", "assign to \(member)", "assign \(member)", "\(member)'s"]
            for pattern in patterns {
                if let range = remaining.range(of: pattern, options: .caseInsensitive) {
                    result.assignedTo = member
                    remaining.removeSubrange(range)
                    break
                }
            }
            if !result.assignedTo.isEmpty { break }
        }

        // 5. Clean up remaining text as task name
        result.name = remaining
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ",.;:-"))
            .trimmingCharacters(in: .whitespaces)

        if let first = result.name.first {
            result.name = first.uppercased() + result.name.dropFirst()
        }

        return result
    }
}

// MARK: - Sticky Note Tips

let parentTips = [
    "A small reward today builds big habits tomorrow.",
    "Kids thrive when they know what's expected.",
    "Celebrate effort, not just results.",
    "Consistency beats perfection every time.",
    "Break big tasks into smaller wins.",
    "Check in with your kids — not just their tasks.",
    "Praise in public, correct in private.",
    "Routine is a superpower for families.",
    "A kind word can turn a tough day around.",
    "Tasks teach responsibility — rewards teach motivation.",
    "The goal isn't perfect kids, it's prepared kids.",
    "Small steps every day lead to big changes.",
    "Lead by example — kids are always watching.",
    "Make time for fun between the to-dos.",
    "Every completed task is a confidence boost.",
]

let childTips = [
    "You got this! One task at a time.",
    "Finished a task? You're basically a superhero.",
    "Pro tip: Start with the easy one first!",
    "Every coin you earn is a high-five from your family.",
    "Even superheroes have chores to do!",
    "The sooner you start, the sooner you're done!",
    "Teamwork makes the dream work!",
    "You're collecting coins like a video game character!",
    "Small tasks today, big rewards tomorrow.",
    "Your family is proud of every task you finish.",
    "Challenge: Can you finish before the timer runs out?",
    "Did you know? Helping out makes you awesome!",
    "One task down? That's one step closer to your goal!",
    "Keep going — you're on a roll!",
    "Fun fact: The more you do, the easier it gets!",
]

let stickyNoteColors: [Color] = [
    Color(red: 1.0, green: 0.95, blue: 0.6),
    Color(red: 0.6, green: 0.95, blue: 0.75),
    Color(red: 0.7, green: 0.85, blue: 1.0),
    Color(red: 1.0, green: 0.8, blue: 0.65),
    Color(red: 0.9, green: 0.75, blue: 1.0),
]

struct CloudBubble: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let tailH: CGFloat = 12
        let bodyH = h - tailH
        let r: CGFloat = min(bodyH / 2, 24)

        path.addRoundedRect(in: CGRect(x: 0, y: 0, width: w, height: bodyH), cornerSize: CGSize(width: r, height: r))

        path.move(to: CGPoint(x: w * 0.25, y: bodyH))
        path.addCurve(
            to: CGPoint(x: w * 0.18, y: h),
            control1: CGPoint(x: w * 0.20, y: bodyH + tailH * 0.6),
            control2: CGPoint(x: w * 0.15, y: h)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.38, y: bodyH),
            control1: CGPoint(x: w * 0.28, y: h - tailH * 0.2),
            control2: CGPoint(x: w * 0.35, y: bodyH)
        )

        return path
    }
}

struct StickyNoteView: View {
    let message: String
    let color: Color
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                    Text("Did you know?")
                        .font(.custom("Noteworthy-Bold", size: 14))
                        .foregroundStyle(.black.opacity(0.5))
                }
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.black.opacity(0.3))
                }
            }

            Text(message)
                .font(.custom("Noteworthy-Bold", size: 16))
                .foregroundStyle(.black.opacity(0.75))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: 280)
        .background(color, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    }
}

// MARK: - Recurring Extension Sheet

struct RecurringExtensionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let groups: [RecurringTaskGroup]
    var theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default")
    var taskLimit: Int?
    var onConfirm: () -> Void
    var onDismiss: () -> Void

    private var totalNewTasks: Int {
        var total = 0
        var remaining = taskLimit
        for group in groups {
            let dates = RecurringTaskExtender.generateExtensionDates(for: group, taskLimit: remaining)
            total += dates.count
            if let r = remaining { remaining = max(0, r - dates.count) }
        }
        return total
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: theme.gradientColors, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 12)

                        VStack(spacing: 10) {
                            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                                .font(.system(size: 48))
                                .foregroundStyle(.cyan)

                            Text("Extend Recurring Tasks")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.primary)

                            Text("Your recurring tasks are ending soon. Extend them for next month?")
                                .font(.subheadline)
                                .foregroundStyle(.primary.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }

                        if let limit = taskLimit {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(.cyan)
                                Text("\(limit) tasks remaining in your plan this month")
                                    .font(.caption)
                                    .foregroundStyle(.primary.opacity(0.7))
                            }
                            .padding(10)
                            .background(.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                        }

                        VStack(spacing: 10) {
                            ForEach(groups) { group in
                                extensionRow(group)
                            }
                        }

                        VStack(spacing: 8) {
                            Text("\(totalNewTasks) new tasks will be created")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)

                            Button {
                                onConfirm()
                                dismiss()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Extend All")
                                }
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(.green, in: RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(totalNewTasks == 0)

                            Button {
                                onDismiss()
                                dismiss()
                            } label: {
                                Text("Not Now")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary.opacity(0.6))
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                }
            }
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .environment(\.colorScheme, theme.colorScheme)
            .navigationTitle("Recurring Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func extensionRow(_ group: RecurringTaskGroup) -> some View {
        let dates = RecurringTaskExtender.generateExtensionDates(for: group, taskLimit: taskLimit)
        return HStack(spacing: 12) {
            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                .font(.title3)
                .foregroundStyle(.cyan)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if !group.assignedTo.isEmpty {
                        Text(group.assignedTo)
                            .font(.caption)
                            .foregroundStyle(.cyan.opacity(0.8))
                    }
                    Text(group.frequency.rawValue)
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.5))
                    if group.reward > 0 {
                        Text("\(Int(group.reward)) coins")
                            .font(.caption)
                            .foregroundStyle(.yellow.opacity(0.8))
                    }
                }
            }

            Spacer()

            Text("+\(dates.count)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.green)
        }
        .padding(14)
        .background(.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.primary.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Monthly Quest

enum QuestRank: String, CaseIterable {
    case rookie = "Rookie"
    case knight = "Knight"
    case ninja = "Ninja"

    var icon: String {
        switch self {
        case .rookie: return "shield.fill"
        case .knight: return "bolt.shield.fill"
        case .ninja: return "flame.fill"
        }
    }

    var color: Color {
        switch self {
        case .rookie: return .gray
        case .knight: return .blue
        case .ninja: return .orange
        }
    }

    var minDays: Int {
        switch self {
        case .rookie: return 0
        case .knight: return 10
        case .ninja: return 20
        }
    }
}

struct MonthlyQuest {
    let activeDays: Int
    let totalDaysInMonth: Int

    var rank: QuestRank {
        if activeDays >= 20 { return .ninja }
        if activeDays >= 10 { return .knight }
        return .rookie
    }

    var nextRank: QuestRank? {
        switch rank {
        case .rookie: return .knight
        case .knight: return .ninja
        case .ninja: return nil
        }
    }

    var progress: Double {
        guard totalDaysInMonth > 0 else { return 0 }
        return min(Double(activeDays) / Double(totalDaysInMonth), 1.0)
    }

    var daysToNextRank: Int? {
        guard let next = nextRank else { return nil }
        return max(0, next.minDays - activeDays)
    }

    static func compute(tasks: [Item], userName: String) -> MonthlyQuest {
        let calendar = Calendar.current
        let now = Date()
        let range = calendar.range(of: .day, in: .month, for: now)!
        let totalDays = range.count

        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!

        let completedThisMonth = tasks.filter {
            $0.assignedTo == userName
            && $0.isApproved
            && !$0.isArchived
            && $0.targetDate >= startOfMonth
            && $0.targetDate <= now
        }

        var uniqueDays = Set<Int>()
        for task in completedThisMonth {
            let day = calendar.component(.day, from: task.targetDate)
            uniqueDays.insert(day)
        }

        return MonthlyQuest(activeDays: uniqueDays.count, totalDaysInMonth: totalDays)
    }
}

struct QuestProgressBar: View {
    let quest: MonthlyQuest
    var userName: String = ""
    var theme: ChildTheme = ChildTheme(themeId: "default", fontId: "default")

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.orange)

            if !userName.isEmpty {
                Text(userName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.textColor)
                Text("·")
                    .foregroundStyle(theme.tertiaryTextColor)
            }

            Text("\(quest.activeDays) day\(quest.activeDays == 1 ? "" : "s")")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(theme.secondaryTextColor)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [quest.rank.color, (quest.nextRank ?? quest.rank).color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, geo.size.width * quest.progress), height: 6)
                }
                .frame(height: 6)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            .frame(height: 6)

            HStack(spacing: 3) {
                Image(systemName: quest.rank.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(quest.rank.color)
                Text(quest.rank.rawValue)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(quest.rank.color)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(quest.rank.color.opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: - Radial Dock Menu

struct RadialDockItem: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let color: Color
    let badge: Int
    let action: () -> Void

    init(icon: String, label: String, color: Color, badge: Int = 0, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.color = color
        self.badge = badge
        self.action = action
    }
}

struct RadialDock: View {
    let items: [RadialDockItem]

    @State private var rotationAngle: Double = 0
    @State private var dragAngle: Double = 0

    private let radius: CGFloat = 130
    private let itemSize: CGFloat = 44
    private let anchorOffset: CGFloat = 30

    private var focusedIndex: Int {
        guard !items.isEmpty else { return 0 }
        let totalAngle = rotationAngle + dragAngle
        let step = .pi / Double(max(items.count, 2))
        let raw = Int(round(-totalAngle / step))
        return max(0, min(items.count - 1, raw))
    }

    var body: some View {
        GeometryReader { geo in
            let anchorX = geo.size.width - anchorOffset
            let anchorY = geo.size.height - geo.safeAreaInsets.bottom - anchorOffset
            let hitRadius = radius + itemSize / 2 + 20

            ZStack {
                Circle()
                    .fill(.black.opacity(0.12))
                    .frame(width: hitRadius * 2, height: hitRadius * 2)
                    .position(x: anchorX, y: anchorY)
                    .allowsHitTesting(false)

                ForEach(0..<max(0, items.count - 1), id: \.self) { index in
                    let angle1 = angleFor(index: index) + rotationAngle + dragAngle
                    let angle2 = angleFor(index: index + 1) + rotationAngle + dragAngle
                    let midAngle = (angle1 + angle2) / 2
                    let innerR = radius - itemSize / 2 - 4
                    let outerR = radius + itemSize / 2 + 4
                    Path { path in
                        path.move(to: CGPoint(
                            x: anchorX + cos(midAngle) * innerR,
                            y: anchorY + sin(midAngle) * innerR
                        ))
                        path.addLine(to: CGPoint(
                            x: anchorX + cos(midAngle) * outerR,
                            y: anchorY + sin(midAngle) * outerR
                        ))
                    }
                    .stroke(.white.opacity(0.5), lineWidth: 2)
                    .allowsHitTesting(false)
                }

                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let baseAngle = angleFor(index: index)
                    let angle = baseAngle + rotationAngle + dragAngle
                    let x = anchorX + cos(angle) * radius
                    let y = anchorY + sin(angle) * radius
                    let isFocused = index == focusedIndex

                    Button {
                        item.action()
                    } label: {
                        VStack(spacing: 4) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: item.icon)
                                    .font(.system(size: isFocused ? 20 : 16, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: isFocused ? 52 : itemSize, height: isFocused ? 52 : itemSize)
                                    .background(item.color, in: Circle())
                                    .shadow(color: item.color.opacity(isFocused ? 0.6 : 0.3), radius: isFocused ? 10 : 4, y: 3)
                                if item.badge > 0 {
                                    Text("\(item.badge)")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(minWidth: 16, minHeight: 16)
                                        .background(.red, in: Circle())
                                        .offset(x: 4, y: -4)
                                }
                            }
                            if isFocused {
                                Text(item.label)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.black.opacity(0.6), in: Capsule())
                                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                            }
                        }
                        .animation(.easeOut(duration: 0.2), value: isFocused)
                    }
                    .position(x: x, y: y)
                }

                Circle()
                    .fill(.clear)
                    .frame(width: hitRadius * 2, height: hitRadius * 2)
                    .contentShape(Circle())
                    .position(x: anchorX, y: anchorY)
                    .gesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { value in
                                let center = CGPoint(x: anchorX, y: anchorY)
                                let startAngle = atan2(value.startLocation.y - center.y, value.startLocation.x - center.x)
                                let currentAngle = atan2(value.location.y - center.y, value.location.x - center.x)
                                var delta = currentAngle - startAngle
                                if delta > .pi { delta -= 2 * .pi }
                                if delta < -.pi { delta += 2 * .pi }
                                dragAngle = delta
                            }
                            .onEnded { _ in
                                rotationAngle += dragAngle
                                dragAngle = 0
                                snapToNearest()
                            }
                    )
            }
        }
        .ignoresSafeArea()
    }

    private func angleFor(index: Int) -> Double {
        let count = max(items.count, 2)
        let totalArc = .pi * 0.8
        let startAngle = .pi + (.pi - totalArc) / 2
        let step = totalArc / Double(count - 1)
        return startAngle + step * Double(index)
    }

    private func snapToNearest() {
        let step = .pi / Double(max(items.count, 2))
        let snapped = round(rotationAngle / step) * step
        let maxRotation = 0.0
        let minRotation = -step * Double(items.count - 1)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            rotationAngle = max(minRotation, min(maxRotation, snapped))
        }
    }
}

// MARK: - Goal Model

@Model
final class Goal {
    var id: UUID
    var name: String
    var category: String
    var icon: String
    var assignedTo: String
    var createdBy: String
    var status: String
    var targetDate: Date
    var createdAt: Date
    var isCustom: Bool
    var templateId: String

    init(id: UUID = UUID(), name: String, category: String, icon: String, assignedTo: String, createdBy: String, targetDate: Date = Date(), isCustom: Bool = false, templateId: String = "") {
        self.id = id
        self.name = name
        self.category = category
        self.icon = icon
        self.assignedTo = assignedTo
        self.createdBy = createdBy
        self.status = "active"
        self.targetDate = targetDate
        self.createdAt = Date()
        self.isCustom = isCustom
        self.templateId = templateId
    }

    var isActive: Bool { status == "active" }
    var isCompleted: Bool { status == "completed" }
    var isPaused: Bool { status == "paused" }

    func progress(from tasks: [Item]) -> Double {
        let goalTasks = tasks.filter { $0.goalId == id.uuidString }
        guard !goalTasks.isEmpty else { return 0 }
        let done = goalTasks.filter { $0.isApproved }.count
        return Double(done) / Double(goalTasks.count)
    }

    func tasksDone(from tasks: [Item]) -> Int {
        tasks.filter { $0.goalId == id.uuidString && $0.isApproved }.count
    }

    func totalTasks(from tasks: [Item]) -> Int {
        tasks.filter { $0.goalId == id.uuidString }.count
    }
}

// MARK: - Goal Templates

struct SuggestedTask {
    let name: String
    let frequency: RecurrenceType
    let occurrences: Int
    let reward: Int
    let hour: Int
    let minute: Int
}

struct GoalTemplate: Identifiable {
    let id: String
    let name: String
    let category: GoalCategory
    let icon: String
    let audience: Set<GoalAudience>
    let durationDays: Int
    let suggestedTasks: [SuggestedTask]
}

enum GoalAudience: String, CaseIterable {
    case child, parent, individual
}

enum GoalCategory: String, CaseIterable, Identifiable {
    case education = "Education"
    case wellbeing = "Well-being"
    case lifestyle = "Lifestyle"
    case finance = "Finance"
    case skills = "Skills"
    case fitness = "Fitness"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .education: return "book.fill"
        case .wellbeing: return "heart.fill"
        case .lifestyle: return "house.fill"
        case .finance: return "banknote.fill"
        case .skills: return "star.fill"
        case .fitness: return "figure.run"
        }
    }

    var color: Color {
        switch self {
        case .education: return .blue
        case .wellbeing: return .pink
        case .lifestyle: return .orange
        case .finance: return .green
        case .skills: return .purple
        case .fitness: return .red
        }
    }
}

struct GoalTemplateCatalog {
    static let all: [GoalTemplate] = [
        // EDUCATION
        GoalTemplate(id: "ace_exams", name: "Ace My Exams", category: .education, icon: "graduationcap.fill", audience: [.child], durationDays: 30, suggestedTasks: [
            SuggestedTask(name: "Study session", frequency: .daily, occurrences: 30, reward: 3, hour: 16, minute: 0),
            SuggestedTask(name: "Practice problems", frequency: .daily, occurrences: 30, reward: 2, hour: 17, minute: 0),
            SuggestedTask(name: "Review notes", frequency: .daily, occurrences: 30, reward: 2, hour: 18, minute: 0),
        ]),
        GoalTemplate(id: "read_books", name: "Read 10 Books", category: .education, icon: "books.vertical.fill", audience: [.child, .parent, .individual], durationDays: 60, suggestedTasks: [
            SuggestedTask(name: "Read for 30 minutes", frequency: .daily, occurrences: 60, reward: 2, hour: 20, minute: 0),
            SuggestedTask(name: "Write book summary", frequency: .weekly, occurrences: 8, reward: 5, hour: 18, minute: 0),
        ]),
        GoalTemplate(id: "homework_routine", name: "Homework Routine", category: .education, icon: "pencil.and.ruler.fill", audience: [.child], durationDays: 30, suggestedTasks: [
            SuggestedTask(name: "Complete homework", frequency: .daily, occurrences: 20, reward: 3, hour: 16, minute: 0),
            SuggestedTask(name: "Pack school bag", frequency: .daily, occurrences: 20, reward: 1, hour: 20, minute: 0),
        ]),
        GoalTemplate(id: "learn_multiplication", name: "Learn Multiplication", category: .education, icon: "number.circle.fill", audience: [.child], durationDays: 30, suggestedTasks: [
            SuggestedTask(name: "Math drills", frequency: .daily, occurrences: 30, reward: 2, hour: 16, minute: 30),
            SuggestedTask(name: "Times table quiz", frequency: .weekly, occurrences: 4, reward: 5, hour: 17, minute: 0),
        ]),

        // WELL-BEING
        GoalTemplate(id: "weight_loss", name: "Weight Loss", category: .wellbeing, icon: "scalemass.fill", audience: [.parent, .individual], durationDays: 60, suggestedTasks: [
            SuggestedTask(name: "Exercise 30 min", frequency: .daily, occurrences: 60, reward: 3, hour: 7, minute: 0),
            SuggestedTask(name: "Drink 8 glasses of water", frequency: .daily, occurrences: 60, reward: 1, hour: 9, minute: 0),
            SuggestedTask(name: "Meal prep healthy food", frequency: .weekly, occurrences: 8, reward: 5, hour: 10, minute: 0),
            SuggestedTask(name: "Log weight", frequency: .weekly, occurrences: 8, reward: 2, hour: 8, minute: 0),
        ]),
        GoalTemplate(id: "morning_routine", name: "Morning Routine", category: .wellbeing, icon: "sunrise.fill", audience: [.child, .parent, .individual], durationDays: 30, suggestedTasks: [
            SuggestedTask(name: "Wake up on time", frequency: .daily, occurrences: 30, reward: 2, hour: 7, minute: 0),
            SuggestedTask(name: "Make bed", frequency: .daily, occurrences: 30, reward: 1, hour: 7, minute: 15),
            SuggestedTask(name: "Eat breakfast", frequency: .daily, occurrences: 30, reward: 1, hour: 7, minute: 30),
        ]),
        GoalTemplate(id: "meditate_daily", name: "Meditate Daily", category: .wellbeing, icon: "brain.head.profile.fill", audience: [.parent, .individual], durationDays: 30, suggestedTasks: [
            SuggestedTask(name: "Meditate 10 minutes", frequency: .daily, occurrences: 30, reward: 3, hour: 7, minute: 0),
            SuggestedTask(name: "Gratitude journaling", frequency: .daily, occurrences: 30, reward: 2, hour: 21, minute: 0),
        ]),
        GoalTemplate(id: "sleep_routine", name: "Sleep by 9pm", category: .wellbeing, icon: "moon.fill", audience: [.child], durationDays: 30, suggestedTasks: [
            SuggestedTask(name: "Brush teeth", frequency: .daily, occurrences: 30, reward: 1, hour: 20, minute: 30),
            SuggestedTask(name: "Lights out by 9pm", frequency: .daily, occurrences: 30, reward: 2, hour: 21, minute: 0),
        ]),
        GoalTemplate(id: "drink_water", name: "Drink More Water", category: .wellbeing, icon: "drop.fill", audience: [.child, .parent, .individual], durationDays: 30, suggestedTasks: [
            SuggestedTask(name: "Drink 8 glasses of water", frequency: .daily, occurrences: 30, reward: 2, hour: 12, minute: 0),
        ]),

        // LIFESTYLE
        GoalTemplate(id: "clean_home", name: "Clean Home", category: .lifestyle, icon: "sparkles", audience: [.parent, .individual], durationDays: 30, suggestedTasks: [
            SuggestedTask(name: "Vacuum/sweep floors", frequency: .weekly, occurrences: 4, reward: 5, hour: 10, minute: 0),
            SuggestedTask(name: "Wipe kitchen counters", frequency: .daily, occurrences: 30, reward: 1, hour: 20, minute: 0),
            SuggestedTask(name: "Clean bathrooms", frequency: .weekly, occurrences: 4, reward: 5, hour: 11, minute: 0),
            SuggestedTask(name: "Do laundry", frequency: .weekly, occurrences: 4, reward: 3, hour: 9, minute: 0),
        ]),
        GoalTemplate(id: "keep_room_clean", name: "Keep Room Clean", category: .lifestyle, icon: "bed.double.fill", audience: [.child], durationDays: 30, suggestedTasks: [
            SuggestedTask(name: "Make bed", frequency: .daily, occurrences: 30, reward: 1, hour: 7, minute: 30),
            SuggestedTask(name: "Tidy room", frequency: .daily, occurrences: 30, reward: 2, hour: 19, minute: 0),
            SuggestedTask(name: "Organize desk", frequency: .weekly, occurrences: 4, reward: 3, hour: 17, minute: 0),
        ]),
        GoalTemplate(id: "meal_prep", name: "Meal Prep Weekly", category: .lifestyle, icon: "fork.knife.circle.fill", audience: [.parent, .individual], durationDays: 30, suggestedTasks: [
            SuggestedTask(name: "Plan weekly meals", frequency: .weekly, occurrences: 4, reward: 3, hour: 10, minute: 0),
            SuggestedTask(name: "Grocery shopping", frequency: .weekly, occurrences: 4, reward: 3, hour: 11, minute: 0),
            SuggestedTask(name: "Prep meals for the week", frequency: .weekly, occurrences: 4, reward: 5, hour: 14, minute: 0),
        ]),

        // FINANCE
        GoalTemplate(id: "save_money", name: "Save Money", category: .finance, icon: "dollarsign.circle.fill", audience: [.parent, .individual], durationDays: 30, suggestedTasks: [
            SuggestedTask(name: "Track daily spending", frequency: .daily, occurrences: 30, reward: 2, hour: 21, minute: 0),
            SuggestedTask(name: "Review weekly budget", frequency: .weekly, occurrences: 4, reward: 5, hour: 19, minute: 0),
            SuggestedTask(name: "No unnecessary purchases today", frequency: .daily, occurrences: 30, reward: 3, hour: 20, minute: 0),
        ]),
        GoalTemplate(id: "save_pocket_money", name: "Save Pocket Money", category: .finance, icon: "piggy.bank.fill", audience: [.child], durationDays: 30, suggestedTasks: [
            SuggestedTask(name: "Save coins (no spending today)", frequency: .daily, occurrences: 30, reward: 2, hour: 18, minute: 0),
            SuggestedTask(name: "Count savings", frequency: .weekly, occurrences: 4, reward: 3, hour: 17, minute: 0),
        ]),

        // SKILLS
        GoalTemplate(id: "learn_cooking", name: "Learn to Cook", category: .skills, icon: "frying.pan.fill", audience: [.child, .parent, .individual], durationDays: 30, suggestedTasks: [
            SuggestedTask(name: "Cook a new recipe", frequency: .weekly, occurrences: 4, reward: 5, hour: 17, minute: 0),
            SuggestedTask(name: "Help with dinner prep", frequency: .daily, occurrences: 20, reward: 2, hour: 17, minute: 30),
        ]),
        GoalTemplate(id: "practice_piano", name: "Practice Piano", category: .skills, icon: "pianokeys", audience: [.child], durationDays: 30, suggestedTasks: [
            SuggestedTask(name: "Piano practice 20 min", frequency: .daily, occurrences: 30, reward: 3, hour: 16, minute: 0),
            SuggestedTask(name: "Learn a new song", frequency: .weekly, occurrences: 4, reward: 5, hour: 16, minute: 30),
        ]),
        GoalTemplate(id: "learn_coding", name: "Learn Coding", category: .skills, icon: "chevron.left.forwardslash.chevron.right", audience: [.child, .parent, .individual], durationDays: 30, suggestedTasks: [
            SuggestedTask(name: "Coding practice 30 min", frequency: .daily, occurrences: 30, reward: 3, hour: 17, minute: 0),
            SuggestedTask(name: "Complete a coding challenge", frequency: .weekly, occurrences: 4, reward: 5, hour: 18, minute: 0),
        ]),
        GoalTemplate(id: "learn_language", name: "Learn a Language", category: .skills, icon: "globe", audience: [.child, .parent, .individual], durationDays: 60, suggestedTasks: [
            SuggestedTask(name: "Language app lesson", frequency: .daily, occurrences: 60, reward: 2, hour: 18, minute: 0),
            SuggestedTask(name: "Practice vocabulary", frequency: .daily, occurrences: 60, reward: 1, hour: 19, minute: 0),
        ]),

        // FITNESS
        GoalTemplate(id: "run_5k", name: "Run a 5K", category: .fitness, icon: "figure.run", audience: [.parent, .individual], durationDays: 60, suggestedTasks: [
            SuggestedTask(name: "Running session", frequency: .daily, occurrences: 40, reward: 3, hour: 6, minute: 30),
            SuggestedTask(name: "Stretching routine", frequency: .daily, occurrences: 60, reward: 1, hour: 6, minute: 0),
            SuggestedTask(name: "Rest day (no running)", frequency: .weekly, occurrences: 8, reward: 2, hour: 8, minute: 0),
        ]),
        GoalTemplate(id: "gym_3x", name: "Gym 3x/Week", category: .fitness, icon: "dumbbell.fill", audience: [.parent, .individual], durationDays: 30, suggestedTasks: [
            SuggestedTask(name: "Gym workout", frequency: .weekly, occurrences: 12, reward: 5, hour: 7, minute: 0),
        ]),
        GoalTemplate(id: "walk_steps", name: "Walk 5000 Steps", category: .fitness, icon: "figure.walk", audience: [.child, .parent, .individual], durationDays: 30, suggestedTasks: [
            SuggestedTask(name: "Walk 5000 steps", frequency: .daily, occurrences: 30, reward: 2, hour: 17, minute: 0),
        ]),
        GoalTemplate(id: "join_sport", name: "Join a Sport", category: .fitness, icon: "sportscourt.fill", audience: [.child], durationDays: 30, suggestedTasks: [
            SuggestedTask(name: "Sports practice", frequency: .weekly, occurrences: 8, reward: 5, hour: 16, minute: 0),
            SuggestedTask(name: "Exercise at home", frequency: .daily, occurrences: 20, reward: 2, hour: 17, minute: 0),
        ]),
    ]

    static func templates(for audience: GoalAudience) -> [GoalTemplate] {
        all.filter { $0.audience.contains(audience) }
    }

    static func grouped(for audience: GoalAudience) -> [(category: GoalCategory, templates: [GoalTemplate])] {
        let filtered = templates(for: audience)
        return GoalCategory.allCases.compactMap { cat in
            let templates = filtered.filter { $0.category == cat }
            return templates.isEmpty ? nil : (category: cat, templates: templates)
        }
    }
}
