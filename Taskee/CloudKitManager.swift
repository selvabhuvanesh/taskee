//
//  CloudKitManager.swift
//  Taskee
//

import CloudKit
import SwiftData

extension Notification.Name {
    static let cloudKitDataChanged = Notification.Name("cloudKitDataChanged")
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
                avatar: record["avatar"] as? String ?? "person.circle.fill",
                familyCode: record["familyCode"] as? String ?? "",
                totalEarned: (record["totalEarned"] as? NSNumber)?.doubleValue ?? 0,
                memberID: recordID.recordName
            )
        } catch {
            return nil
        }
    }

    // MARK: - Push Task

    @discardableResult
    func pushTask(_ task: Item, familyCode: String) async -> Bool {
        guard !familyCode.isEmpty else { return false }

        let recordID = CKRecord.ID(recordName: task.id.uuidString)
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch {
            record = CKRecord(recordType: "TaskRecord", recordID: recordID)
        }

        record["familyCode"] = familyCode
        record["name"] = task.name
        record["targetDate"] = task.targetDate as NSDate
        record["assignedTo"] = task.assignedTo
        record["reward"] = NSNumber(value: task.reward)
        record["status"] = task.status
        record["createdByChild"] = NSNumber(value: task.createdByChild ? 1 : 0)
        record["isArchived"] = NSNumber(value: task.isArchived ? 1 : 0)

        do {
            try await database.save(record)
            return true
        } catch {
            lastSyncError = error.localizedDescription
            return false
        }
    }

    // MARK: - Push Member

    @discardableResult
    func pushMember(_ member: FamilyMember, familyCode: String) async -> Bool {
        guard !familyCode.isEmpty else { return false }

        let recordID = CKRecord.ID(recordName: member.id.uuidString)
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch {
            record = CKRecord(recordType: "MemberRecord", recordID: recordID)
        }

        record["familyCode"] = familyCode
        record["name"] = member.name
        record["memberRole"] = member.memberRole
        record["avatar"] = member.avatar
        record["totalEarned"] = NSNumber(value: member.totalEarned)
        record["appleUserID"] = member.appleUserID

        do {
            try await database.save(record)
            return true
        } catch {
            lastSyncError = error.localizedDescription
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

    // MARK: - Full Sync

    func syncAll(context: ModelContext, familyCode: String) async {
        guard !familyCode.isEmpty else { return }
        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }

        await syncTasks(context: context, familyCode: familyCode)
        await syncMembers(context: context, familyCode: familyCode)
        try? context.save()
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

    private func syncTasks(context: ModelContext, familyCode: String) async {
        let remoteRecords = await fetchAllRecords(type: "TaskRecord", familyCode: familyCode)

        let descriptor = FetchDescriptor<Item>()
        let localTasks = (try? context.fetch(descriptor)) ?? []
        let localByID = Dictionary(uniqueKeysWithValues: localTasks.map { ($0.id.uuidString, $0) })
        let remoteIDs = Set(remoteRecords.map { $0.recordID.recordName })

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
            } else if let uuid = UUID(uuidString: idStr) {
                let item = Item(
                    id: uuid,
                    name: record["name"] as? String ?? "",
                    targetDate: record["targetDate"] as? Date ?? Date(),
                    assignedTo: record["assignedTo"] as? String ?? "",
                    reward: (record["reward"] as? NSNumber)?.doubleValue ?? 0,
                    status: record["status"] as? String ?? "open",
                    createdByChild: ((record["createdByChild"] as? NSNumber)?.intValue ?? 0) == 1
                )
                item.isArchived = ((record["isArchived"] as? NSNumber)?.intValue ?? 0) == 1
                context.insert(item)
            }
        }

        for task in localTasks where !remoteIDs.contains(task.id.uuidString) {
            await pushTask(task, familyCode: familyCode)
        }
    }

    private func syncMembers(context: ModelContext, familyCode: String) async {
        let remoteRecords = await fetchAllRecords(type: "MemberRecord", familyCode: familyCode)

        let descriptor = FetchDescriptor<FamilyMember>()
        let localMembers = (try? context.fetch(descriptor)) ?? []
        let localByID = Dictionary(uniqueKeysWithValues: localMembers.map { ($0.id.uuidString, $0) })
        let remoteIDs = Set(remoteRecords.map { $0.recordID.recordName })

        for record in remoteRecords {
            let idStr = record.recordID.recordName
            if let local = localByID[idStr] {
                local.name = record["name"] as? String ?? local.name
                local.memberRole = record["memberRole"] as? String ?? local.memberRole
                local.avatar = record["avatar"] as? String ?? local.avatar
                local.totalEarned = (record["totalEarned"] as? NSNumber)?.doubleValue ?? local.totalEarned
                local.appleUserID = record["appleUserID"] as? String ?? local.appleUserID
            } else if let uuid = UUID(uuidString: idStr) {
                let member = FamilyMember(
                    id: uuid,
                    name: record["name"] as? String ?? "",
                    memberRole: record["memberRole"] as? String ?? "child",
                    avatar: record["avatar"] as? String ?? "person.circle.fill",
                    appleUserID: record["appleUserID"] as? String ?? ""
                )
                member.totalEarned = (record["totalEarned"] as? NSNumber)?.doubleValue ?? 0
                context.insert(member)
            }
        }

        for member in localMembers where !remoteIDs.contains(member.id.uuidString) {
            await pushMember(member, familyCode: familyCode)
        }
    }

    // MARK: - Remote Notifications

    func sendRemoteNotification(familyCode: String, title: String, body: String, category: String = "") async {
        guard !familyCode.isEmpty else { return }

        let record = CKRecord(recordType: "NotificationRecord")
        record["familyCode"] = familyCode
        record["title"] = title
        record["body"] = body
        record["category"] = category
        record["createdAt"] = Date() as NSDate

        do {
            try await database.save(record)
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    // MARK: - Subscriptions

    func setupSubscriptions(familyCode: String) async {
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
        await createAlertSubscription(
            id: "notif-changes-\(familyCode)",
            familyCode: familyCode
        )
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

    private func createAlertSubscription(id: String, familyCode: String) async {
        do {
            _ = try await database.subscription(for: id)
            return
        } catch { }

        let predicate = NSPredicate(format: "familyCode == %@", familyCode)
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
        info.soundName = "default"
        info.shouldBadge = true
        sub.notificationInfo = info

        do {
            try await database.save(sub)
        } catch {
            lastSyncError = error.localizedDescription
        }
    }
}
