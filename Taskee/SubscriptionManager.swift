//
//  SubscriptionManager.swift
//  Taskee
//

import StoreKit
import SwiftData

@Observable
final class SubscriptionManager {

    // MARK: - Product IDs (register these in App Store Connect)

    static let familyMonthly  = "com.taskee.family.monthly"
    static let familyAnnual   = "com.taskee.family.annual"
    static let proMonthly     = "com.taskee.pro.monthly"
    static let proAnnual      = "com.taskee.pro.annual"

    private static let familyIDs: Set<String> = [familyMonthly, familyAnnual]
    private static let proIDs: Set<String>    = [proMonthly, proAnnual]
    private static let allIDs: Set<String>    = familyIDs.union(proIDs)

    // MARK: - State

    enum Tier: String, Comparable {
        case free, family, pro

        var displayName: String {
            switch self {
            case .free: return "Free"
            case .family: return "Basic"
            case .pro: return "Pro"
            }
        }

        static func < (lhs: Tier, rhs: Tier) -> Bool {
            let order: [Tier] = [.free, .family, .pro]
            return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
        }
    }

    private(set) var tier: Tier = ScreenshotHelper.isScreenshotMode ? .pro : .free
    var products: [Product] = []
    var purchaseError: String?

    // MARK: - Free Trial (1 week)

    private static let trialStartKey = "freeTrialStartDate"
    private static let trialDuration: TimeInterval = 7 * 24 * 60 * 60

    var trialStartDate: Date {
        if let stored = UserDefaults.standard.object(forKey: Self.trialStartKey) as? Date {
            return stored
        }
        let now = Date()
        UserDefaults.standard.set(now, forKey: Self.trialStartKey)
        return now
    }

    var isTrialActive: Bool {
        guard tier == .free else { return false }
        return Date().timeIntervalSince(trialStartDate) < Self.trialDuration
    }

    var isTrialExpired: Bool {
        guard tier == .free else { return false }
        return !isTrialActive
    }

    var trialDaysRemaining: Int {
        guard tier == .free else { return 0 }
        let elapsed = Date().timeIntervalSince(trialStartDate)
        let remaining = Self.trialDuration - elapsed
        return max(0, Int(ceil(remaining / (24 * 60 * 60))))
    }

    // MARK: - Tier Limits

    var maxMembers: Int {
        switch tier {
        case .free:   return isTrialActive ? 4 : 0
        case .family: return 6
        case .pro:    return 10
        }
    }

    var maxTasksPerMonth: Int? {
        switch tier {
        case .free:   return isTrialActive ? 50 : 0
        case .family: return 500
        case .pro:    return 2000
        }
    }

    var maxPickupsPerDay: Int? {
        switch tier {
        case .free:   return 20
        case .family: return 30
        case .pro:    return nil
        }
    }

    // MARK: - Anti-Bot: Rate Limiting

    private var lastTaskCreated: Date = .distantPast
    private let taskCooldown: TimeInterval = 10

    var canCreateTask: Bool {
        Date().timeIntervalSince(lastTaskCreated) >= taskCooldown
    }

    func recordTaskCreation() {
        lastTaskCreated = Date()
    }

    // MARK: - Anti-Bot: Pickup Rate Limiting

    func pickupsUsedToday() -> Int {
        UserDefaults.standard.integer(forKey: pickupKey())
    }

    func recordPickup() {
        let key = pickupKey()
        UserDefaults.standard.set(pickupsUsedToday() + 1, forKey: key)
    }

    func canSendPickup() -> Bool {
        guard let limit = maxPickupsPerDay else { return true }
        return pickupsUsedToday() < limit
    }

    private func pickupKey() -> String {
        let day = Calendar.current.startOfDay(for: Date())
        let stamp = Int(day.timeIntervalSince1970)
        return "pickups-\(stamp)"
    }

    // MARK: - Task Count This Month

    func tasksCreatedThisMonth(allTasks: [Item]) -> Int {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        return allTasks.filter { $0.targetDate >= startOfMonth }.count
    }

    func canCreateMoreTasks(allTasks: [Item]) -> Bool {
        guard let limit = maxTasksPerMonth else { return true }
        return tasksCreatedThisMonth(allTasks: allTasks) < limit
    }

    func tasksRemaining(allTasks: [Item]) -> Int? {
        guard let limit = maxTasksPerMonth else { return nil }
        return max(0, limit - tasksCreatedThisMonth(allTasks: allTasks))
    }

    // MARK: - Member Count

    func canAddMember(currentCount: Int) -> Bool {
        currentCount < maxMembers
    }

    // MARK: - StoreKit 2

    func loadProducts() async {
        guard !ScreenshotHelper.isScreenshotMode else { return }
        do {
            products = try await Product.products(for: SubscriptionManager.allIDs)
                .sorted { $0.price < $1.price }
        } catch {
            purchaseError = "Failed to load products."
        }
    }

    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                if Self.proIDs.contains(transaction.productID) {
                    localTier = .pro
                } else if Self.familyIDs.contains(transaction.productID) {
                    localTier = .family
                }
                tier = max(localTier, familyTier)
                onTierChanged?(tier)
                return true
            case .userCancelled:
                return false
            case .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            purchaseError = error.localizedDescription
            return false
        }
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await refreshTier()
    }

    private(set) var familyTier: Tier = .free

    func setFamilyTier(_ tierString: String) {
        familyTier = Tier(rawValue: tierString) ?? .free
        tier = max(localTier, familyTier)
    }

    private var localTier: Tier = .free

    func refreshTier() async {
        guard !ScreenshotHelper.isScreenshotMode else { return }
        var resolved: Tier = .free

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if SubscriptionManager.proIDs.contains(transaction.productID) {
                resolved = .pro
                break
            } else if SubscriptionManager.familyIDs.contains(transaction.productID) {
                resolved = .family
            }
        }

        localTier = resolved
        tier = max(localTier, familyTier)
    }

    var onTierChanged: ((Tier) -> Void)?

    func listenForTransactions() async {
        guard !ScreenshotHelper.isScreenshotMode else { return }
        for await result in Transaction.updates {
            if let _ = try? checkVerified(result) {
                await refreshTier()
                onTierChanged?(tier)
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw StoreError.unverified
        }
    }

    enum StoreError: Error {
        case unverified
    }
}
