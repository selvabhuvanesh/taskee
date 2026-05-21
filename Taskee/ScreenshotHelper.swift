import SwiftUI
import SwiftData

enum ScreenshotHelper {
    static var isScreenshotMode: Bool {
        ProcessInfo.processInfo.arguments.contains("-screenshotMode")
    }

    static var screenshotRole: String {
        if let idx = ProcessInfo.processInfo.arguments.firstIndex(of: "-screenshotRole"),
           idx + 1 < ProcessInfo.processInfo.arguments.count {
            return ProcessInfo.processInfo.arguments[idx + 1]
        }
        return "parent"
    }

    static var screenshotScreen: String {
        if let idx = ProcessInfo.processInfo.arguments.firstIndex(of: "-screenshotScreen"),
           idx + 1 < ProcessInfo.processInfo.arguments.count {
            return ProcessInfo.processInfo.arguments[idx + 1]
        }
        return "dashboard"
    }

    static var shouldOpenChat: Bool {
        screenshotScreen == "chat"
    }

    static func setupMockAuth(_ authManager: AuthManager) {
        let role = screenshotRole
        authManager.isLoggedIn = true
        authManager.role = role
        authManager.familyCode = "FAM123"
        authManager.hasCompletedOnboarding = true
        authManager.isPendingApproval = false

        if role == "parent" {
            authManager.userName = "Sarah"
            authManager.appleUserID = "mock-parent-001"
            authManager.avatar = "av02"
        } else {
            authManager.userName = "Alex"
            authManager.appleUserID = "mock-child-001"
            authManager.avatar = "av05"
        }
    }

    @MainActor
    static func populateMockData(context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Family members
        let parent = FamilyMember(name: "Sarah", memberRole: "parent", avatar: "av02", isAccepted: true, totalEarned: 0, appleUserID: "mock-parent-001")
        let child1 = FamilyMember(name: "Alex", memberRole: "child", avatar: "av05", isAccepted: true, totalEarned: 42, appleUserID: "mock-child-001")
        let child2 = FamilyMember(name: "Emma", memberRole: "child", avatar: "av08", isAccepted: true, totalEarned: 35, appleUserID: "mock-child-002")

        context.insert(parent)
        context.insert(child1)
        context.insert(child2)

        // Tasks for Alex - today
        let tasks: [(String, String, Double, String, Int, String)] = [
            ("Clean your room", "Alex", 5, "open", 9, "none"),
            ("Practice piano", "Alex", 3, "approved", 8, "none"),
            ("Walk the dog", "Alex", 4, "open", 16, "none"),
            ("Read for 30 minutes", "Alex", 2, "inReview", 15, "none"),
            ("Do homework", "Emma", 5, "open", 10, "none"),
            ("Set the dinner table", "Emma", 2, "approved", 18, "none"),
            ("Water the plants", "Emma", 3, "open", 11, "none"),
            ("Tidy up toys", "Alex", 2, "open", 17, "none"),
        ]

        for (name, assignee, reward, status, hour, transport) in tasks {
            let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: today)!
            let task = Item(
                name: name,
                targetDate: date,
                assignedTo: assignee,
                reward: reward,
                status: status,
                createdBy: "Sarah",
                createdByID: "mock-parent-001",
                transportType: transport
            )
            context.insert(task)
        }

        // A task with a gift
        let giftTask = Item(
            name: "Finish science project",
            targetDate: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: today)!,
            assignedTo: "Alex",
            reward: 10,
            status: "open",
            giftText: "Movie night with the family!",
            createdBy: "Sarah",
            createdByID: "mock-parent-001"
        )
        context.insert(giftTask)

        // Tomorrow tasks
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let tomorrowTasks: [(String, String, Double, Int)] = [
            ("Soccer practice", "Alex", 3, 10),
            ("Art class project", "Emma", 4, 14),
            ("Pack school bag", "Alex", 1, 20),
        ]

        for (name, assignee, reward, hour) in tomorrowTasks {
            let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: tomorrow)!
            let task = Item(
                name: name,
                targetDate: date,
                assignedTo: assignee,
                reward: reward,
                createdBy: "Sarah",
                createdByID: "mock-parent-001"
            )
            context.insert(task)
        }

        // Chat messages
        let chatBase = Date().addingTimeInterval(-3600)
        let messages: [(String, String, String, String, TimeInterval)] = [
            ("Sarah", "av02", "mock-parent-001", "Good morning everyone! Have a great day today!", 0),
            ("Alex", "av05", "mock-child-001", "I finished cleaning my room!", 300),
            ("Sarah", "av02", "mock-parent-001", "Great job Alex! Keep it up!", 420),
            ("Emma", "av08", "mock-child-002", "Can we go to the park after I finish my tasks?", 600),
            ("Sarah", "av02", "mock-parent-001", "Sure! Finish everything first and we'll go", 720),
            ("Alex", "av05", "mock-child-001", "I want to come too!", 780),
        ]

        for (name, avatar, userId, text, offset) in messages {
            let msg = ChatMessage(
                senderName: name,
                senderAvatar: avatar,
                senderAppleUserID: userId,
                text: text,
                sentAt: chatBase.addingTimeInterval(offset)
            )
            context.insert(msg)
        }

        // Shopping list items
        let shoppingItems: [(String, String, Bool)] = [
            ("Milk", "Sarah", false),
            ("Bread", "Sarah", true),
            ("Apples", "Emma", false),
            ("Notebook", "Alex", false),
        ]

        for (name, addedBy, bought) in shoppingItems {
            let item = ShoppingItem(name: name, addedBy: addedBy, isBought: bought)
            context.insert(item)
        }

        try? context.save()
    }

    static func makeInMemoryContainer() -> ModelContainer {
        let schema = Schema([
            Item.self,
            FamilyMember.self,
            RewardRedemption.self,
            SurpriseGift.self,
            ShoppingItem.self,
            ChatMessage.self,
            AnnualReminder.self,
            FamilyProject.self,
            ProjectIdea.self,
            ProjectVote.self,
            WishListItem.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }
}
