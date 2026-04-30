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

    init(id: UUID = UUID(), name: String, memberRole: String = "child", avatar: String = "av01", isAccepted: Bool = true, totalEarned: Double = 0, appleUserID: String = "") {
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

struct AvatarView: View {
    let avatarId: String
    let size: CGFloat

    var body: some View {
        if let config = avatarConfig(for: avatarId) {
            AvatarFaceView(config: config, size: size)
        } else if let animalConfig = animalAvatarConfig(for: avatarId) {
            AnimalAvatarFaceView(config: animalConfig, size: size)
        } else {
            Image(systemName: avatarId.isEmpty ? "star.fill" : avatarId)
                .font(.system(size: size * 0.45))
                .foregroundStyle(avatarColor(for: avatarId))
                .frame(width: size, height: size)
                .background(avatarColor(for: avatarId).opacity(0.2), in: Circle())
        }
    }
}

// MARK: - App Share

let appStoreURL = URL(string: "https://apps.apple.com/app/taskee/id0000000000")!
let parentShareMessage = "Taskee has been a game-changer for our family! My kids actually WANT to do their chores now — they earn coins, redeem rewards, and it's taught them real responsibility. Best parenting tool I've found. You've got to try it:"

let childShareMessage = "Okay so my parents got this app called Taskee and it's actually awesome?? I get coins every time I finish a chore and I can save up for real rewards! It's like turning chores into a game. You NEED to get your parents to download this:"

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

// MARK: - Coin Display

struct CoinDisplay: View {
    let count: Int
    let earned: Bool

    private var baseColor: Color {
        earned ? Color(red: 1.0, green: 0.84, blue: 0.0) : Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.8)
    }

    var body: some View {
        HStack(spacing: 3) {
            if earned {
                Text("Earned")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(baseColor)
            }
            if count <= 5 {
                ForEach(0..<count, id: \.self) { _ in
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(baseColor)
                }
            } else {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(baseColor)
                    .overlay(
                        Text("\(count)")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.black)
                    )
            }
        }
    }
}

// MARK: - Accent Color

let calmAccent = Color.blue

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
                        .font(.caption.weight(.bold))
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
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.black.opacity(0.75))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 22)
        .frame(maxWidth: 280)
        .background(color, in: CloudBubble())
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    }
}
