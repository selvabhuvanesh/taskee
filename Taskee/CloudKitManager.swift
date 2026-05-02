//
//  CloudKitManager.swift
//  Taskee
//

import CloudKit
import SwiftData

extension Notification.Name {
    static let cloudKitDataChanged = Notification.Name("cloudKitDataChanged")
    static let checkPickupNotification = Notification.Name("checkPickupNotification")
}

enum CloudValidationResult {
    case valid
    case invalid
    case cloudUnavailable
}

@MainActor
@Observable
final class CloudKitManager {

    var isSyncing = false
    var lastSyncError: String?
    private(set) var isAvailable = false

    private let container = CKContainer(identifier: "iCloud.com.selvabhuvanesh.taskee")
    private var database: CKDatabase { container.publicCloudDatabase }

    // MARK: - Availability

    func checkAvailability() async {
        do {
            let status = try await container.accountStatus()
            isAvailable = (status == .available)
        } catch {
            isAvailable = false
        }
    }

    // MARK: - Family Code Registration & Validation

    func familyAlreadyExists(appleUserID: String) async -> String? {
        guard !appleUserID.isEmpty else { return nil }

        let predicate = NSPredicate(format: "createdByAppleID == %@", appleUserID)
        let query = CKQuery(recordType: "FamilyRecord", predicate: predicate)

        do {
            let (results, _) = try await database.records(matching: query, resultsLimit: 1)
            if let (_, result) = results.first,
               let record = try? result.get() {
                return record["familyCode"] as? String
            }
            return nil
        } catch {
            return nil
        }
    }

    @discardableResult
    func registerFamily(code: String, createdBy: String, appleUserID: String = "") async -> Bool {
        guard !code.isEmpty else { return false }

        let recordID = CKRecord.ID(recordName: "family-\(code)")
        let record = CKRecord(recordType: "FamilyRecord", recordID: recordID)
        record["familyCode"] = code
        record["createdBy"] = createdBy
        record["createdByAppleID"] = appleUserID
        record["createdAt"] = Date() as NSDate

        do {
            try await database.save(record)
            return true
        } catch {
            lastSyncError = error.localizedDescription
            return false
        }
    }

    func validateFamilyCode(_ code: String) async -> CloudValidationResult {
        guard !code.isEmpty else { return .invalid }

        let predicate = NSPredicate(format: "familyCode == %@", code)
        let query = CKQuery(recordType: "FamilyRecord", predicate: predicate)

        do {
            let (results, _) = try await database.records(matching: query, resultsLimit: 1)
            return results.isEmpty ? .invalid : .valid
        } catch {
            lastSyncError = error.localizedDescription
            return .cloudUnavailable
        }
    }

    // MARK: - Member Count

    func memberCount(familyCode: String) async -> Int {
        guard !familyCode.isEmpty else { return 0 }

        let predicate = NSPredicate(format: "familyCode == %@", familyCode)
        let query = CKQuery(recordType: "MemberRecord", predicate: predicate)

        do {
            let (results, _) = try await database.records(matching: query)
            return results.count
        } catch {
            return 0
        }
    }

    // MARK: - Lookup Existing Member

    struct ExistingMemberInfo {
        let name: String
        let memberRole: String
        let avatar: String
        let familyCode: String
        let totalEarned: Double
        let memberID: String
    }

    func checkMemberAccepted(appleUserID: String) async -> Bool {
        guard !appleUserID.isEmpty else { return false }

        let predicate = NSPredicate(format: "appleUserID == %@", appleUserID)
        let query = CKQuery(recordType: "MemberRecord", predicate: predicate)

        do {
            let (results, _) = try await database.records(matching: query, resultsLimit: 1)
            guard let (_, result) = results.first,
                  let record = try? result.get() else { return false }
            return ((record["isAccepted"] as? NSNumber)?.intValue ?? 1) == 1
        } catch {
            return false
        }
    }

    func lookupExistingMember(appleUserID: String) async -> ExistingMemberInfo? {
        guard !appleUserID.isEmpty else { return nil }

        let predicate = NSPredicate(format: "appleUserID == %@", appleUserID)
        let query = CKQuery(recordType: "MemberRecord", predicate: predicate)

        do {
            let (results, _) = try await database.records(matching: query, resultsLimit: 1)
            guard let (recordID, result) = results.first,
                  let record = try? result.get() else { return nil }

            return ExistingMemberInfo(
                name: record["name"] as? String ?? "",
                memberRole: record["memberRole"] as? String ?? "child",
                avatar: record["avatar"] as? String ?? "star.fill",
                familyCode: record["familyCode"] as? String ?? "",
                totalEarned: (record["totalEarned"] as? NSNumber)?.doubleValue ?? 0,
                memberID: recordID.recordName
            )
        } catch {
            return nil
        }
    }

    // MARK: - Push Task

    struct TaskSnapshot {
        let id: String
        let name: String
        let targetDate: Date
        let assignedTo: String
        let reward: Double
        let status: String
        let createdByChild: Bool
        let isArchived: Bool
        let isRecurring: Bool
        let giftText: String
        let giftRevealed: Bool
        let createdBy: String
        let createdByID: String

        init(_ task: Item) {
            self.id = task.id.uuidString
            self.name = task.name
            self.targetDate = task.targetDate
            self.assignedTo = task.assignedTo
            self.reward = task.reward
            self.status = task.status
            self.createdByChild = task.createdByChild
            self.isArchived = task.isArchived
            self.isRecurring = task.isRecurring
            self.giftText = task.giftText
            self.giftRevealed = task.giftRevealed
            self.createdBy = task.createdBy
            self.createdByID = task.createdByID
        }
    }

    @discardableResult
    func pushTask(_ task: Item, familyCode: String) async -> Bool {
        await pushTaskSnapshot(TaskSnapshot(task), familyCode: familyCode)
    }

    @discardableResult
    func pushTaskSnapshot(_ snap: TaskSnapshot, familyCode: String) async -> Bool {
        guard !familyCode.isEmpty else { return false }

        let recordID = CKRecord.ID(recordName: snap.id)
        let record = CKRecord(recordType: "TaskRecord", recordID: recordID)
        record["familyCode"] = familyCode
        record["name"] = snap.name
        record["targetDate"] = snap.targetDate as NSDate
        record["assignedTo"] = snap.assignedTo
        record["reward"] = NSNumber(value: snap.reward)
        record["status"] = snap.status
        record["createdByChild"] = NSNumber(value: snap.createdByChild ? 1 : 0)
        record["isArchived"] = NSNumber(value: snap.isArchived ? 1 : 0)
        record["isRecurring"] = NSNumber(value: snap.isRecurring ? 1 : 0)
        record["giftText"] = snap.giftText
        record["giftRevealed"] = NSNumber(value: snap.giftRevealed ? 1 : 0)
        record["createdBy"] = snap.createdBy
        record["createdByID"] = snap.createdByID

        return await saveRecord(record)
    }

    // MARK: - Push Member

    @discardableResult
    func pushMember(_ member: FamilyMember, familyCode: String) async -> Bool {
        guard !familyCode.isEmpty else { return false }

        let id = member.id.uuidString
        let name = member.name
        let role = member.memberRole
        let avatar = member.avatar
        let earned = member.totalEarned
        let appleID = member.appleUserID

        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: "MemberRecord", recordID: recordID)
        let accepted = member.isAccepted

        record["familyCode"] = familyCode
        record["name"] = name
        record["memberRole"] = role
        record["avatar"] = avatar
        record["totalEarned"] = NSNumber(value: earned)
        record["appleUserID"] = appleID
        record["isAccepted"] = NSNumber(value: accepted ? 1 : 0)

        if avatar.hasPrefix("photo_") {
            let photoID = String(avatar.dropFirst(6))
            let url = avatarPhotoURL(photoID: photoID)
            if FileManager.default.fileExists(atPath: url.path) {
                record["avatarPhoto"] = CKAsset(fileURL: url)
            }
        }

        return await saveRecord(record)
    }

    var lastPushResult: String = ""

    private func saveRecord(_ record: CKRecord) async -> Bool {
        let status = record["status"] as? String ?? "n/a"
        let type = record.recordType
        let id = record.recordID.recordName

        do {
            let (saveResults, _) = try await database.modifyRecords(
                saving: [record],
                deleting: [],
                savePolicy: .allKeys
            )
            for (_, result) in saveResults {
                if case .failure(let error) = result {
                    lastSyncError = error.localizedDescription
                    lastPushResult = "FAIL \(type) \(id) status=\(status): \(error.localizedDescription)"
                    return false
                }
            }
            lastPushResult = "OK \(type) \(id) status=\(status)"
            return true
        } catch {
            lastSyncError = error.localizedDescription
            lastPushResult = "ERROR \(type) \(id) status=\(status): \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Delete

    func deleteRemoteTask(_ taskID: UUID) async {
        do {
            try await database.deleteRecord(withID: CKRecord.ID(recordName: taskID.uuidString))
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    func deleteRemoteMember(_ memberID: UUID) async {
        do {
            try await database.deleteRecord(withID: CKRecord.ID(recordName: memberID.uuidString))
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    func deleteRemoteTasks(_ taskIDs: [UUID]) async {
        guard !taskIDs.isEmpty else { return }
        let recordIDs = taskIDs.map { CKRecord.ID(recordName: $0.uuidString) }
        do {
            let (_, deleteResults) = try await database.modifyRecords(saving: [], deleting: recordIDs)
            for (_, result) in deleteResults {
                if case .failure(let error) = result {
                    lastSyncError = error.localizedDescription
                }
            }
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    // MARK: - Archive Old Tasks

    func archiveOldTasks(context: ModelContext, familyCode: String) async {
        guard !familyCode.isEmpty else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        let descriptor = FetchDescriptor<Item>()
        let localTasks = (try? context.fetch(descriptor)) ?? []
        let toArchive = localTasks.filter { $0.isApproved && $0.targetDate < cutoff }
        guard !toArchive.isEmpty else { return }

        var savedRecords: [CKRecord] = []
        var deleteIDs: [CKRecord.ID] = []

        for task in toArchive {
            let record = CKRecord(recordType: "ArchivedTaskRecord", recordID: CKRecord.ID(recordName: "arch-\(task.id.uuidString)"))
            record["familyCode"] = familyCode
            record["name"] = task.name
            record["targetDate"] = task.targetDate as NSDate
            record["assignedTo"] = task.assignedTo
            record["reward"] = NSNumber(value: task.reward)
            record["status"] = task.status
            record["createdByChild"] = NSNumber(value: task.createdByChild ? 1 : 0)
            record["isRecurring"] = NSNumber(value: task.isRecurring ? 1 : 0)
            record["giftText"] = task.giftText
            record["giftRevealed"] = NSNumber(value: task.giftRevealed ? 1 : 0)
            record["createdBy"] = task.createdBy
            record["createdByID"] = task.createdByID
            savedRecords.append(record)
            deleteIDs.append(CKRecord.ID(recordName: task.id.uuidString))
        }

        do {
            let batchSize = 400
            for start in stride(from: 0, to: savedRecords.count, by: batchSize) {
                let end = min(start + batchSize, savedRecords.count)
                let saveBatch = Array(savedRecords[start..<end])
                let deleteBatch = Array(deleteIDs[start..<end])
                try await database.modifyRecords(saving: saveBatch, deleting: deleteBatch)
            }

            for task in toArchive {
                context.delete(task)
            }
            try? context.save()
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    struct ArchivedTask: Identifiable {
        let id: String
        let name: String
        let targetDate: Date
        let assignedTo: String
        let reward: Double
        let status: String
        let giftText: String
    }

    func fetchArchivedTasks(familyCode: String) async -> [ArchivedTask] {
        guard !familyCode.isEmpty else { return [] }
        let records = await fetchAllRecords(type: "ArchivedTaskRecord", familyCode: familyCode)
        return records.compactMap { record in
            ArchivedTask(
                id: record.recordID.recordName,
                name: record["name"] as? String ?? "",
                targetDate: record["targetDate"] as? Date ?? Date(),
                assignedTo: record["assignedTo"] as? String ?? "",
                reward: (record["reward"] as? NSNumber)?.doubleValue ?? 0,
                status: record["status"] as? String ?? "approved",
                giftText: record["giftText"] as? String ?? ""
            )
        }
        .sorted { $0.targetDate > $1.targetDate }
    }

    // MARK: - Full Sync

    private var syncInProgress = false

    struct SyncedTask {
        let id: UUID
        let name: String
        let targetDate: Date
        let assignedTo: String
        let createdBy: String
    }

    func syncAll(context: ModelContext, familyCode: String, onNewTasks: (([SyncedTask]) -> Void)? = nil) async {
        guard !familyCode.isEmpty, !syncInProgress else { return }
        syncInProgress = true
        isSyncing = true
        lastSyncError = nil
        defer {
            isSyncing = false
            syncInProgress = false
        }

        let newTasks = await syncTasks(context: context, familyCode: familyCode)
        await syncMembers(context: context, familyCode: familyCode)
        await syncRedemptions(context: context, familyCode: familyCode)
        try? context.save()

        if !newTasks.isEmpty {
            onNewTasks?(newTasks)
        }
    }

    private func fetchAllRecords(type: String, familyCode: String) async -> [CKRecord] {
        let predicate = NSPredicate(format: "familyCode == %@", familyCode)
        let query = CKQuery(recordType: type, predicate: predicate)
        var all: [CKRecord] = []

        do {
            var (results, cursor) = try await database.records(matching: query)
            all.append(contentsOf: results.compactMap { try? $0.1.get() })

            while let c = cursor {
                let (more, next) = try await database.records(continuingMatchFrom: c)
                all.append(contentsOf: more.compactMap { try? $0.1.get() })
                cursor = next
            }
        } catch {
            lastSyncError = error.localizedDescription
        }

        return all
    }

    @discardableResult
    private func syncTasks(context: ModelContext, familyCode: String) async -> [SyncedTask] {
        let remoteRecords = await fetchAllRecords(type: "TaskRecord", familyCode: familyCode)

        let descriptor = FetchDescriptor<Item>()
        let localTasks = (try? context.fetch(descriptor)) ?? []
        let localByID = Dictionary(uniqueKeysWithValues: localTasks.map { ($0.id.uuidString, $0) })
        let remoteIDs = Set(remoteRecords.map { $0.recordID.recordName })
        var newTasks: [SyncedTask] = []

        for record in remoteRecords {
            let idStr = record.recordID.recordName
            if let local = localByID[idStr] {
                local.name = record["name"] as? String ?? local.name
                local.targetDate = record["targetDate"] as? Date ?? local.targetDate
                local.assignedTo = record["assignedTo"] as? String ?? local.assignedTo
                local.reward = (record["reward"] as? NSNumber)?.doubleValue ?? local.reward
                local.status = record["status"] as? String ?? local.status
                local.createdByChild = ((record["createdByChild"] as? NSNumber)?.intValue ?? 0) == 1
                local.isArchived = ((record["isArchived"] as? NSNumber)?.intValue ?? 0) == 1
                local.isRecurring = ((record["isRecurring"] as? NSNumber)?.intValue ?? 0) == 1
                local.giftText = record["giftText"] as? String ?? local.giftText
                local.giftRevealed = ((record["giftRevealed"] as? NSNumber)?.intValue ?? 0) == 1
                let remoteCreatedBy = record["createdBy"] as? String ?? ""
                if !remoteCreatedBy.isEmpty { local.createdBy = remoteCreatedBy }
                let remoteCreatedByID = record["createdByID"] as? String ?? ""
                if !remoteCreatedByID.isEmpty { local.createdByID = remoteCreatedByID }
            } else if let uuid = UUID(uuidString: idStr) {
                let name = record["name"] as? String ?? ""
                let targetDate = record["targetDate"] as? Date ?? Date()
                let assignedTo = record["assignedTo"] as? String ?? ""
                let status = record["status"] as? String ?? "open"
                let item = Item(
                    id: uuid,
                    name: name,
                    targetDate: targetDate,
                    assignedTo: assignedTo,
                    reward: (record["reward"] as? NSNumber)?.doubleValue ?? 0,
                    status: status,
                    createdByChild: ((record["createdByChild"] as? NSNumber)?.intValue ?? 0) == 1,
                    isRecurring: ((record["isRecurring"] as? NSNumber)?.intValue ?? 0) == 1,
                    giftText: record["giftText"] as? String ?? "",
                    createdBy: record["createdBy"] as? String ?? "",
                    createdByID: record["createdByID"] as? String ?? ""
                )
                item.isArchived = ((record["isArchived"] as? NSNumber)?.intValue ?? 0) == 1
                item.giftRevealed = ((record["giftRevealed"] as? NSNumber)?.intValue ?? 0) == 1
                context.insert(item)

                if status == "open" {
                    let createdBy = record["createdBy"] as? String ?? ""
                    newTasks.append(SyncedTask(id: uuid, name: name, targetDate: targetDate, assignedTo: assignedTo, createdBy: createdBy))
                }
            }
        }

        for task in localTasks where !remoteIDs.contains(task.id.uuidString) {
            context.delete(task)
        }

        return newTasks
    }

    private func syncMembers(context: ModelContext, familyCode: String) async {
        let remoteRecords = await fetchAllRecords(type: "MemberRecord", familyCode: familyCode)

        let descriptor = FetchDescriptor<FamilyMember>()
        let localMembers = (try? context.fetch(descriptor)) ?? []
        let localByID = Dictionary(uniqueKeysWithValues: localMembers.map { ($0.id.uuidString, $0) })
        let remoteIDs = Set(remoteRecords.map { $0.recordID.recordName })

        for record in remoteRecords {
            let idStr = record.recordID.recordName
            let remoteAvatar = record["avatar"] as? String ?? "star.fill"
            cacheAvatarPhotoIfNeeded(avatar: remoteAvatar, record: record)

            if let local = localByID[idStr] {
                local.name = record["name"] as? String ?? local.name
                local.memberRole = record["memberRole"] as? String ?? local.memberRole
                local.avatar = remoteAvatar
                local.totalEarned = (record["totalEarned"] as? NSNumber)?.doubleValue ?? local.totalEarned
                local.appleUserID = record["appleUserID"] as? String ?? local.appleUserID
                local.isAccepted = ((record["isAccepted"] as? NSNumber)?.intValue ?? 1) == 1
            } else if let uuid = UUID(uuidString: idStr) {
                let member = FamilyMember(
                    id: uuid,
                    name: record["name"] as? String ?? "",
                    memberRole: record["memberRole"] as? String ?? "child",
                    avatar: remoteAvatar,
                    isAccepted: ((record["isAccepted"] as? NSNumber)?.intValue ?? 1) == 1,
                    appleUserID: record["appleUserID"] as? String ?? ""
                )
                member.totalEarned = (record["totalEarned"] as? NSNumber)?.doubleValue ?? 0
                context.insert(member)
            }
        }

        for member in localMembers where !remoteIDs.contains(member.id.uuidString) {
            context.delete(member)
        }
    }

    private func cacheAvatarPhotoIfNeeded(avatar: String, record: CKRecord) {
        guard avatar.hasPrefix("photo_") else { return }
        let photoID = String(avatar.dropFirst(6))
        let localURL = avatarPhotoURL(photoID: photoID)
        guard !FileManager.default.fileExists(atPath: localURL.path) else { return }
        guard let asset = record["avatarPhoto"] as? CKAsset, let fileURL = asset.fileURL else { return }
        try? FileManager.default.copyItem(at: fileURL, to: localURL)
    }

    // MARK: - Redemptions

    func pushRedemption(_ redemption: RewardRedemption, familyCode: String) async -> Bool {
        let id = redemption.id.uuidString
        let childName = redemption.childName
        let coinAmount = redemption.coinAmount
        let type = redemption.redemptionType
        let desc = redemption.itemDescription
        let status = redemption.status
        let rejectReason = redemption.rejectReason
        let createdAt = redemption.createdAt
        let resolvedAt = redemption.resolvedAt

        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: "RedemptionRecord", recordID: recordID)
        record["familyCode"] = familyCode
        record["childName"] = childName
        record["coinAmount"] = coinAmount as NSNumber
        record["redemptionType"] = type
        record["itemDescription"] = desc
        record["status"] = status
        record["rejectReason"] = rejectReason
        record["createdAt"] = createdAt as NSDate
        if let resolved = resolvedAt {
            record["resolvedAt"] = resolved as NSDate
        }
        return await saveRecord(record)
    }

    private func syncRedemptions(context: ModelContext, familyCode: String) async {
        let remoteRecords = await fetchAllRecords(type: "RedemptionRecord", familyCode: familyCode)

        let descriptor = FetchDescriptor<RewardRedemption>()
        let local = (try? context.fetch(descriptor)) ?? []
        let localByID = Dictionary(uniqueKeysWithValues: local.map { ($0.id.uuidString, $0) })
        let remoteIDs = Set(remoteRecords.map { $0.recordID.recordName })

        for record in remoteRecords {
            let idStr = record.recordID.recordName
            if let existing = localByID[idStr] {
                existing.childName = record["childName"] as? String ?? existing.childName
                existing.coinAmount = (record["coinAmount"] as? NSNumber)?.intValue ?? existing.coinAmount
                existing.redemptionType = record["redemptionType"] as? String ?? existing.redemptionType
                existing.itemDescription = record["itemDescription"] as? String ?? existing.itemDescription
                existing.status = record["status"] as? String ?? existing.status
                existing.rejectReason = record["rejectReason"] as? String ?? existing.rejectReason
                existing.createdAt = record["createdAt"] as? Date ?? existing.createdAt
                existing.resolvedAt = record["resolvedAt"] as? Date
            } else if let uuid = UUID(uuidString: idStr) {
                let r = RewardRedemption(
                    id: uuid,
                    childName: record["childName"] as? String ?? "",
                    coinAmount: (record["coinAmount"] as? NSNumber)?.intValue ?? 0,
                    redemptionType: record["redemptionType"] as? String ?? "other",
                    itemDescription: record["itemDescription"] as? String ?? "",
                    status: record["status"] as? String ?? "pending"
                )
                r.rejectReason = record["rejectReason"] as? String ?? ""
                r.createdAt = record["createdAt"] as? Date ?? Date()
                r.resolvedAt = record["resolvedAt"] as? Date
                context.insert(r)
            }
        }

        for item in local where !remoteIDs.contains(item.id.uuidString) {
            context.delete(item)
        }
    }

    // MARK: - Fetch Notifications

    struct NotificationItem: Identifiable {
        let id: String
        let title: String
        let body: String
        let category: String
        let senderAvatar: String
        let senderName: String
        let createdAt: Date
    }

    struct NotificationFetchResult {
        let notifications: [NotificationItem]
        let error: String?
        let debugInfo: String
    }

    func fetchNotifications(familyCode: String, limit: Int = 50) async -> NotificationFetchResult {
        guard !familyCode.isEmpty else {
            return NotificationFetchResult(notifications: [], error: "Family code is empty", debugInfo: "code: (empty)")
        }

        let predicate = NSPredicate(format: "familyCode == %@", familyCode)
        let query = CKQuery(recordType: "NotificationRecord", predicate: predicate)

        do {
            var allRecords: [CKRecord] = []
            var (results, cursor) = try await database.records(matching: query)
            allRecords.append(contentsOf: results.compactMap { try? $0.1.get() })

            while let c = cursor {
                let (more, next) = try await database.records(continuingMatchFrom: c)
                allRecords.append(contentsOf: more.compactMap { try? $0.1.get() })
                cursor = next
            }

            let items = allRecords
                .compactMap { record in
                    NotificationItem(
                        id: record.recordID.recordName,
                        title: record["title"] as? String ?? "",
                        body: record["body"] as? String ?? "",
                        category: record["category"] as? String ?? "",
                        senderAvatar: record["senderAvatar"] as? String ?? "",
                        senderName: record["senderName"] as? String ?? "",
                        createdAt: record["createdAt"] as? Date ?? Date()
                    )
                }
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(limit)
                .map { $0 }

            return NotificationFetchResult(
                notifications: items,
                error: nil,
                debugInfo: "code: \(familyCode) | found: \(allRecords.count)"
            )
        } catch {
            return NotificationFetchResult(
                notifications: [],
                error: error.localizedDescription,
                debugInfo: "code: \(familyCode) | error"
            )
        }
    }

    func deleteNotification(id: String) async -> Bool {
        let recordID = CKRecord.ID(recordName: id)
        do {
            try await database.deleteRecord(withID: recordID)
            return true
        } catch {
            lastSyncError = error.localizedDescription
            return false
        }
    }

    func deleteAllNotifications(familyCode: String) async -> Int {
        guard !familyCode.isEmpty else { return 0 }

        let predicate = NSPredicate(format: "familyCode == %@", familyCode)
        let query = CKQuery(recordType: "NotificationRecord", predicate: predicate)

        do {
            var idsToDelete: [CKRecord.ID] = []
            var (results, cursor) = try await database.records(matching: query)
            idsToDelete.append(contentsOf: results.compactMap { try? $0.1.get() }.map { $0.recordID })

            while let c = cursor {
                let (more, next) = try await database.records(continuingMatchFrom: c)
                idsToDelete.append(contentsOf: more.compactMap { try? $0.1.get() }.map { $0.recordID })
                cursor = next
            }

            guard !idsToDelete.isEmpty else { return 0 }

            let batchSize = 400
            for batch in stride(from: 0, to: idsToDelete.count, by: batchSize) {
                let end = min(batch + batchSize, idsToDelete.count)
                let batchIDs = Array(idsToDelete[batch..<end])
                let (_, deleteResults) = try await database.modifyRecords(saving: [], deleting: batchIDs)
                for (_, result) in deleteResults {
                    if case .failure(let error) = result {
                        lastSyncError = error.localizedDescription
                    }
                }
            }

            return idsToDelete.count
        } catch {
            lastSyncError = error.localizedDescription
            return 0
        }
    }

    // MARK: - Remote Notifications

    func sendRemoteNotification(familyCode: String, title: String, body: String, category: String = "", senderAvatar: String = "", senderName: String = "", targetAppleUserID: String = "") async {
        guard !familyCode.isEmpty else { return }

        let record = CKRecord(recordType: "NotificationRecord")
        record["familyCode"] = familyCode
        record["title"] = title
        record["body"] = body
        record["category"] = category
        record["senderAvatar"] = senderAvatar
        record["senderName"] = senderName
        record["targetAppleUserID"] = targetAppleUserID
        record["createdAt"] = Date() as NSDate

        do {
            try await database.save(record)
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    struct RemoteNotification {
        let recordID: String
        let title: String
        let body: String
        let category: String
        let senderName: String
    }

    func fetchUnseenNotifications(familyCode: String, appleUserID: String) async -> [RemoteNotification] {
        guard !familyCode.isEmpty, !appleUserID.isEmpty else { return [] }

        let seenIDs = Set(UserDefaults.standard.stringArray(forKey: "seenRemoteNotifIDs") ?? [])
        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
        let predicate = NSPredicate(
            format: "familyCode == %@ AND targetAppleUserID == %@ AND createdAt > %@",
            familyCode, appleUserID, cutoff as NSDate
        )
        let query = CKQuery(recordType: "NotificationRecord", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        do {
            let (results, _) = try await database.records(matching: query, resultsLimit: 20)
            var notifications: [RemoteNotification] = []
            for (recordID, result) in results {
                let id = recordID.recordName
                guard !seenIDs.contains(id) else { continue }
                if let record = try? result.get() {
                    notifications.append(RemoteNotification(
                        recordID: id,
                        title: record["title"] as? String ?? "",
                        body: record["body"] as? String ?? "",
                        category: record["category"] as? String ?? "",
                        senderName: record["senderName"] as? String ?? ""
                    ))
                }
            }
            return notifications
        } catch {
            return []
        }
    }

    static func markNotificationsSeen(_ ids: [String]) {
        var seen = UserDefaults.standard.stringArray(forKey: "seenRemoteNotifIDs") ?? []
        seen.append(contentsOf: ids)
        if seen.count > 500 { seen = Array(seen.suffix(500)) }
        UserDefaults.standard.set(seen, forKey: "seenRemoteNotifIDs")
    }

    // MARK: - Family Subscription Tier

    func pushFamilyTier(_ tier: String, familyCode: String) async {
        guard !familyCode.isEmpty else { return }
        let recordID = CKRecord.ID(recordName: "family-\(familyCode)")
        do {
            let record = try await database.record(for: recordID)
            record["subscriptionTier"] = tier
            try await database.save(record)
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    func fetchFamilyTier(familyCode: String) async -> String? {
        guard !familyCode.isEmpty else { return nil }
        let recordID = CKRecord.ID(recordName: "family-\(familyCode)")
        do {
            let record = try await database.record(for: recordID)
            return record["subscriptionTier"] as? String
        } catch {
            return nil
        }
    }

    // MARK: - Backfill createdBy

    func backfillCreatedBy(context: ModelContext, familyCode: String, userName: String, appleUserID: String = "") async {
        guard !familyCode.isEmpty, !userName.isEmpty else { return }
        let key = "createdByBackfill3-\(userName)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let descriptor = FetchDescriptor<Item>()
        let tasks = (try? context.fetch(descriptor)) ?? []

        let memberDescriptor = FetchDescriptor<FamilyMember>()
        let members = (try? context.fetch(memberDescriptor)) ?? []
        let childNames = Set(members.filter { $0.isChild }.map { $0.name })

        var updated: [Item] = []
        for task in tasks {
            if childNames.contains(task.assignedTo) { continue }
            let isMine = task.assignedTo == userName || task.assignedTo.isEmpty || task.createdBy == userName
            guard isMine else { continue }
            var changed = false
            if task.createdByID.isEmpty {
                task.createdBy = userName
                task.createdByID = appleUserID
                changed = true
            }
            if task.assignedTo.isEmpty {
                task.assignedTo = userName
                changed = true
            }
            if changed { updated.append(task) }
        }

        if !updated.isEmpty {
            try? context.save()
            for task in updated {
                await pushTask(task, familyCode: familyCode)
            }
        }

        UserDefaults.standard.set(true, forKey: key)
    }

    // MARK: - Fetch Latest Pickup

    func fetchLatestPickup(familyCode: String) async -> (childName: String, body: String)? {
        guard !familyCode.isEmpty else { return nil }

        let predicate = NSPredicate(format: "familyCode == %@ AND category == %@", familyCode, "PICKUP_REQUEST")
        let query = CKQuery(recordType: "NotificationRecord", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        do {
            let (results, _) = try await database.records(matching: query, resultsLimit: 1)
            guard let (_, result) = results.first,
                  let record = try? result.get() else { return nil }
            let senderName = record["senderName"] as? String ?? ""
            let body = record["body"] as? String ?? "\(senderName) wants to be picked up!"
            return (senderName, body)
        } catch {
            return nil
        }
    }

    func lookupMemberAppleUserID(name: String, familyCode: String) async -> String? {
        guard !familyCode.isEmpty, !name.isEmpty else { return nil }

        let predicate = NSPredicate(format: "familyCode == %@ AND name == %@", familyCode, name)
        let query = CKQuery(recordType: "MemberRecord", predicate: predicate)

        do {
            let (results, _) = try await database.records(matching: query, resultsLimit: 5)
            for (_, result) in results {
                if let record = try? result.get(),
                   let appleID = record["appleUserID"] as? String,
                   !appleID.isEmpty {
                    return appleID
                }
            }
        } catch { }
        return nil
    }

    func fetchRecentAssignedNotification(familyCode: String, appleUserID: String) async -> (title: String, body: String)? {
        guard !familyCode.isEmpty, !appleUserID.isEmpty else { return nil }

        let cutoff = Date().addingTimeInterval(-30)
        let predicate = NSPredicate(
            format: "familyCode == %@ AND targetAppleUserID == %@ AND category == %@ AND createdAt > %@",
            familyCode, appleUserID, "TASK_ASSIGNED", cutoff as NSDate
        )
        let query = CKQuery(recordType: "NotificationRecord", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        do {
            let (results, _) = try await database.records(matching: query, resultsLimit: 1)
            guard let (_, result) = results.first,
                  let record = try? result.get() else { return nil }
            let title = record["title"] as? String ?? "New Task Assigned"
            let body = record["body"] as? String ?? ""
            return (title, body)
        } catch {
            return nil
        }
    }

    // MARK: - Subscriptions

    func setupSubscriptions(familyCode: String, appleUserID: String = "", role: String = "") async {
        guard !familyCode.isEmpty else { return }

        await createSubscription(
            id: "task-changes-\(familyCode)",
            recordType: "TaskRecord",
            familyCode: familyCode
        )
        await createSubscription(
            id: "member-changes-\(familyCode)",
            recordType: "MemberRecord",
            familyCode: familyCode
        )
        await createSubscription(
            id: "family-changes-\(familyCode)",
            recordType: "FamilyRecord",
            familyCode: familyCode
        )
        await createSubscription(
            id: "notif-changes-\(familyCode)",
            recordType: "NotificationRecord",
            familyCode: familyCode
        )
        await createSilentSubscription(
            id: "pickup-notif-\(familyCode)",
            familyCode: familyCode,
            category: "PICKUP_REQUEST"
        )

        if !appleUserID.isEmpty {
            await createTargetedAlertSubscription(
                id: "targeted-notif-\(appleUserID)",
                familyCode: familyCode,
                targetAppleUserID: appleUserID,
                excludeCategories: ["TASK_REMINDER", "TASK_ASSIGNED"]
            )
            await createTargetedAlertSubscription(
                id: "targeted-reminder-\(appleUserID)",
                familyCode: familyCode,
                targetAppleUserID: appleUserID,
                onlyCategory: "TASK_REMINDER",
                soundName: "reminder.wav"
            )
            await createTargetedAlertSubscription(
                id: "targeted-assigned-\(appleUserID)",
                familyCode: familyCode,
                targetAppleUserID: appleUserID,
                onlyCategory: "TASK_ASSIGNED",
                soundName: "reminder.wav"
            )
        }

        if role == "parent" {
            await createTargetedAlertSubscription(
                id: "parent-notif-\(familyCode)",
                familyCode: familyCode,
                targetAppleUserID: "parents"
            )
        }
    }

    private func createSubscription(id: String, recordType: String, familyCode: String) async {
        do {
            _ = try await database.subscription(for: id)
            return
        } catch { }

        let predicate = NSPredicate(format: "familyCode == %@", familyCode)
        let sub = CKQuerySubscription(
            recordType: recordType,
            predicate: predicate,
            subscriptionID: id,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )

        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        sub.notificationInfo = info

        do {
            try await database.save(sub)
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    private func createSilentSubscription(id: String, familyCode: String, category: String) async {
        do {
            try await database.deleteSubscription(withID: id)
        } catch { }

        let predicate = NSPredicate(format: "familyCode == %@ AND category == %@", familyCode, category)
        let sub = CKQuerySubscription(
            recordType: "NotificationRecord",
            predicate: predicate,
            subscriptionID: id,
            options: [.firesOnRecordCreation]
        )

        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        sub.notificationInfo = info

        do {
            try await database.save(sub)
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    private func createTargetedAlertSubscription(id: String, familyCode: String, targetAppleUserID: String, excludeCategories: [String]? = nil, onlyCategory: String? = nil, soundName: String = "default") async {
        do {
            try await database.deleteSubscription(withID: id)
        } catch { }

        let predicate: NSPredicate
        if let only = onlyCategory {
            predicate = NSPredicate(format: "familyCode == %@ AND targetAppleUserID == %@ AND category == %@", familyCode, targetAppleUserID, only)
        } else if let excludes = excludeCategories, !excludes.isEmpty {
            predicate = NSPredicate(format: "familyCode == %@ AND targetAppleUserID == %@ AND NOT (category IN %@)", familyCode, targetAppleUserID, excludes)
        } else {
            predicate = NSPredicate(format: "familyCode == %@ AND targetAppleUserID == %@", familyCode, targetAppleUserID)
        }

        let sub = CKQuerySubscription(
            recordType: "NotificationRecord",
            predicate: predicate,
            subscriptionID: id,
            options: [.firesOnRecordCreation]
        )

        let info = CKSubscription.NotificationInfo()
        info.titleLocalizationKey = "%1$@"
        info.titleLocalizationArgs = ["title"]
        info.alertLocalizationKey = "%1$@"
        info.alertLocalizationArgs = ["body"]
        info.soundName = soundName
        info.shouldBadge = true
        sub.notificationInfo = info

        do {
            try await database.save(sub)
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    private func createAlertSubscription(id: String, familyCode: String, excludeCategories: [String]? = nil, onlyCategory: String? = nil, soundName: String = "default") async {
        do {
            try await database.deleteSubscription(withID: id)
        } catch { }

        let predicate: NSPredicate
        if let only = onlyCategory {
            predicate = NSPredicate(format: "familyCode == %@ AND category == %@", familyCode, only)
        } else if let excludes = excludeCategories, !excludes.isEmpty {
            predicate = NSPredicate(format: "familyCode == %@ AND NOT (category IN %@)", familyCode, excludes)
        } else {
            predicate = NSPredicate(format: "familyCode == %@", familyCode)
        }

        let sub = CKQuerySubscription(
            recordType: "NotificationRecord",
            predicate: predicate,
            subscriptionID: id,
            options: [.firesOnRecordCreation]
        )

        let info = CKSubscription.NotificationInfo()
        info.titleLocalizationKey = "%1$@"
        info.titleLocalizationArgs = ["title"]
        info.alertLocalizationKey = "%1$@"
        info.alertLocalizationArgs = ["body"]
        info.soundName = soundName
        info.shouldBadge = true
        sub.notificationInfo = info

        do {
            try await database.save(sub)
        } catch {
            lastSyncError = error.localizedDescription
        }
    }
}
