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
    private var privateDatabase: CKDatabase { container.privateCloudDatabase }
    private var sharedDatabase: CKDatabase { container.sharedCloudDatabase }

    // MARK: - Private Zone State

    private(set) var familyZoneID: CKRecordZone.ID?
    var hasFamilyZone: Bool { familyZoneID != nil }

    var isZoneOwner: Bool {
        get { UserDefaults.standard.bool(forKey: "ckIsZoneOwner") }
        set { UserDefaults.standard.set(newValue, forKey: "ckIsZoneOwner") }
    }

    private var familyDatabase: CKDatabase {
        guard familyZoneID != nil else { return database }
        return isZoneOwner ? privateDatabase : sharedDatabase
    }

    private func familyRecordID(name: String) -> CKRecord.ID {
        if let zoneID = familyZoneID {
            return CKRecord.ID(recordName: name, zoneID: zoneID)
        }
        return CKRecord.ID(recordName: name)
    }

    // MARK: - Change Token (Delta Sync)

    private func loadChangeToken() -> CKServerChangeToken? {
        guard let data = UserDefaults.standard.data(forKey: "ckZoneChangeToken") else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
    }

    private func saveChangeToken(_ token: CKServerChangeToken) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: "ckZoneChangeToken")
        }
    }

    private func clearChangeToken() {
        UserDefaults.standard.removeObject(forKey: "ckZoneChangeToken")
    }

    // MARK: - Availability

    func checkAvailability() async {
        guard !ScreenshotHelper.isScreenshotMode else {
            isAvailable = false
            return
        }
        do {
            let status = try await container.accountStatus()
            isAvailable = (status == .available)
            if !isAvailable {
                print("[CloudKit] Account not available. Status: \(status.rawValue)")
            } else {
                print("[CloudKit] Account available")
            }
        } catch {
            isAvailable = false
            print("[CloudKit] Account check failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Zone & Share Management

    func ensureFamilyZoneAccess(familyCode: String, appleUserID: String) async {
        guard !familyCode.isEmpty, isAvailable else { return }
        if familyZoneID != nil { return }

        let zoneName = "family-\(familyCode)"
        let zoneID = CKRecordZone.ID(zoneName: zoneName)

        // 1. Check private DB (are we the zone owner?)
        do {
            _ = try await privateDatabase.recordZone(for: zoneID)
            familyZoneID = zoneID
            isZoneOwner = true
            print("[CloudKit] Found owned zone: \(zoneName)")
            await ensureShareExists(familyCode: familyCode)
            return
        } catch {
            print("[CloudKit] Zone not owned: \(error.localizedDescription)")
        }

        // 2. Check shared DB (are we a participant?)
        do {
            let zones = try await sharedDatabase.allRecordZones()
            if let matchedZone = zones.first(where: { $0.zoneID.zoneName == zoneName }) {
                familyZoneID = matchedZone.zoneID
                isZoneOwner = false
                print("[CloudKit] Found shared zone: \(zoneName) owner=\(matchedZone.zoneID.ownerName)")
                return
            }
        } catch {
            print("[CloudKit] Shared zone lookup failed: \(error.localizedDescription)")
        }

        // 3. Zone not found — check if we're the family creator
        let isCreator = await isFamilyCreator(familyCode: familyCode, appleUserID: appleUserID)

        if isCreator {
            await createFamilyZone(familyCode: familyCode)
        } else {
            if let shareURL = await fetchShareURL(familyCode: familyCode) {
                if await acceptFamilyShare(shareURLString: shareURL) {
                    if let actualZoneID = await resolveSharedZoneID(zoneName: zoneName) {
                        familyZoneID = actualZoneID
                    } else {
                        familyZoneID = zoneID
                    }
                    isZoneOwner = false
                    print("[CloudKit] Accepted share for zone: \(zoneName)")
                }
            }
        }
    }

    private func isFamilyCreator(familyCode: String, appleUserID: String) async -> Bool {
        guard !appleUserID.isEmpty else { return false }
        let recordID = CKRecord.ID(recordName: "family-\(familyCode)")
        do {
            let record = try await database.record(for: recordID)
            return (record["createdByAppleID"] as? String) == appleUserID
        } catch {
            return false
        }
    }

    func createFamilyZone(familyCode: String) async {
        let zoneName = "family-\(familyCode)"
        let zoneID = CKRecordZone.ID(zoneName: zoneName)
        let zone = CKRecordZone(zoneID: zoneID)

        do {
            try await privateDatabase.save(zone)
            familyZoneID = zoneID
            isZoneOwner = true
            print("[CloudKit] Created zone: \(zoneName)")

            let share = CKShare(recordZoneID: zoneID)
            share.publicPermission = .readWrite
            share[CKShare.SystemFieldKey.title] = "Taskoot Family"

            try await privateDatabase.save(share)
            if let url = share.url {
                await updateFamilyShareURL(familyCode: familyCode, shareURL: url.absoluteString)
                print("[CloudKit] Share created, URL stored")
            }
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .serverRecordChanged {
            familyZoneID = zoneID
            isZoneOwner = true
            await ensureShareExists(familyCode: familyCode)
        } catch {
            lastSyncError = error.localizedDescription
            print("[CloudKit] Zone creation failed: \(error.localizedDescription)")
        }
    }

    private func ensureShareExists(familyCode: String) async {
        guard let zoneID = familyZoneID, isZoneOwner else { return }
        let existing = await fetchShareURL(familyCode: familyCode)
        if existing != nil { return }

        let share = CKShare(recordZoneID: zoneID)
        share.publicPermission = .readWrite
        share[CKShare.SystemFieldKey.title] = "Taskoot Family"

        do {
            try await privateDatabase.save(share)
            if let url = share.url {
                await updateFamilyShareURL(familyCode: familyCode, shareURL: url.absoluteString)
            }
        } catch {
            print("[CloudKit] Share creation failed: \(error.localizedDescription)")
        }
    }

    func acceptFamilyShare(shareURLString: String) async -> Bool {
        guard let url = URL(string: shareURLString) else { return false }

        do {
            let metadata = try await fetchShareMetadata(url: url)
            try await acceptShare(metadata: metadata)
            return true
        } catch {
            lastSyncError = error.localizedDescription
            print("[CloudKit] Share accept failed: \(error.localizedDescription)")
            return false
        }
    }

    private func fetchShareMetadata(url: URL) async throws -> CKShare.Metadata {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKFetchShareMetadataOperation(shareURLs: [url])
            var resumed = false
            operation.perShareMetadataResultBlock = { _, result in
                guard !resumed else { return }
                resumed = true
                switch result {
                case .success(let metadata):
                    continuation.resume(returning: metadata)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            operation.fetchShareMetadataResultBlock = { result in
                guard !resumed else { return }
                resumed = true
                if case .failure(let error) = result {
                    continuation.resume(throwing: error)
                }
            }
            container.add(operation)
        }
    }

    private func acceptShare(metadata: CKShare.Metadata) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
            var resumed = false
            operation.perShareResultBlock = { _, result in
                guard !resumed else { return }
                resumed = true
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            operation.acceptSharesResultBlock = { result in
                guard !resumed else { return }
                resumed = true
                if case .failure(let error) = result {
                    continuation.resume(throwing: error)
                }
            }
            container.add(operation)
        }
    }

    private func resolveSharedZoneID(zoneName: String) async -> CKRecordZone.ID? {
        do {
            let zones = try await sharedDatabase.allRecordZones()
            return zones.first(where: { $0.zoneID.zoneName == zoneName })?.zoneID
        } catch {
            return nil
        }
    }

    func fetchShareURL(familyCode: String) async -> String? {
        guard !familyCode.isEmpty else { return nil }
        let recordID = CKRecord.ID(recordName: "family-\(familyCode)")
        do {
            let record = try await database.record(for: recordID)
            return record["shareURL"] as? String
        } catch {
            return nil
        }
    }

    private func updateFamilyShareURL(familyCode: String, shareURL: String) async {
        let recordID = CKRecord.ID(recordName: "family-\(familyCode)")
        do {
            let record = try await database.record(for: recordID)
            record["shareURL"] = shareURL
            try await database.save(record)
        } catch {
            print("[CloudKit] Failed to store share URL: \(error.localizedDescription)")
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
        let lastRemindedAt: Date?
        let transportType: String
        let projectId: String

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
            self.lastRemindedAt = task.lastRemindedAt
            self.transportType = task.transportType
            self.projectId = task.projectId
        }
    }

    @discardableResult
    func pushTask(_ task: Item, familyCode: String) async -> Bool {
        await pushTaskSnapshot(TaskSnapshot(task), familyCode: familyCode)
    }

    @discardableResult
    func pushTaskSnapshot(_ snap: TaskSnapshot, familyCode: String) async -> Bool {
        guard !familyCode.isEmpty else { return false }

        let recordID = familyRecordID(name: snap.id)
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
        if let reminded = snap.lastRemindedAt {
            record["lastRemindedAt"] = reminded as NSDate
        }
        record["transportType"] = snap.transportType
        record["projectId"] = snap.projectId

        return await saveRecord(record, to: familyDatabase)
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
        if let pickup = member.lastPickupAt {
            record["lastPickupAt"] = pickup as NSDate
        }
        if let ack = member.lastPickupAckAt {
            record["lastPickupAckAt"] = ack as NSDate
        }
        if !member.lastPickupAckBy.isEmpty {
            record["lastPickupAckBy"] = member.lastPickupAckBy
        }

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

    private func isTransientCKError(_ error: Error) -> Bool {
        guard let ckError = error as? CKError else { return false }
        switch ckError.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable,
             .requestRateLimited, .zoneBusy, .serverResponseLost:
            return true
        default:
            return false
        }
    }

    private func retryDelay(for error: Error, attempt: Int) -> Double {
        if let ckError = error as? CKError,
           let suggested = ckError.userInfo[CKErrorRetryAfterKey] as? Double {
            return suggested
        }
        return min(Double(1 << attempt), 30)
    }

    private func saveRecord(_ record: CKRecord, to targetDB: CKDatabase? = nil) async -> Bool {
        let db = targetDB ?? database
        let status = record["status"] as? String ?? "n/a"
        let type = record.recordType
        let id = record.recordID.recordName
        let maxAttempts = 4

        for attempt in 0..<maxAttempts {
            do {
                let (saveResults, _) = try await db.modifyRecords(
                    saving: [record],
                    deleting: [],
                    savePolicy: .allKeys
                )
                var perRecordError: Error?
                for (_, result) in saveResults {
                    if case .failure(let error) = result {
                        perRecordError = error
                    }
                }
                if let error = perRecordError {
                    if attempt < maxAttempts - 1 && isTransientCKError(error) {
                        let delay = retryDelay(for: error, attempt: attempt)
                        print("[CloudKit] SAVE RETRY \(type) \(id) attempt \(attempt + 1), waiting \(delay)s: \(error.localizedDescription)")
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                    lastSyncError = error.localizedDescription
                    lastPushResult = "FAIL \(type) \(id) status=\(status): \(error.localizedDescription)"
                    print("[CloudKit] SAVE FAIL \(type) \(id): \(error.localizedDescription)")
                    return false
                }
                lastPushResult = "OK \(type) \(id) status=\(status)"
                print("[CloudKit] SAVE OK \(type) \(id)")
                return true
            } catch {
                if attempt < maxAttempts - 1 && isTransientCKError(error) {
                    let delay = retryDelay(for: error, attempt: attempt)
                    print("[CloudKit] SAVE RETRY \(type) \(id) attempt \(attempt + 1), waiting \(delay)s: \(error.localizedDescription)")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                lastSyncError = error.localizedDescription
                lastPushResult = "ERROR \(type) \(id) status=\(status): \(error.localizedDescription)"
                print("[CloudKit] SAVE ERROR \(type) \(id): \(error.localizedDescription)")
                return false
            }
        }
        return false
    }

    // MARK: - Delete

    func deleteRemoteTask(_ taskID: UUID) async {
        let recordID = familyRecordID(name: taskID.uuidString)
        do {
            try await familyDatabase.deleteRecord(withID: recordID)
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
        let recordIDs = taskIDs.map { familyRecordID(name: $0.uuidString) }
        do {
            let (_, deleteResults) = try await familyDatabase.modifyRecords(saving: [], deleting: recordIDs)
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
        let toArchive = localTasks.filter { ($0.isApproved || $0.isMissed) && $0.targetDate < cutoff }
        guard !toArchive.isEmpty else { return }

        var savedRecords: [CKRecord] = []
        var deleteIDs: [CKRecord.ID] = []

        for task in toArchive {
            let archID = familyRecordID(name: "arch-\(task.id.uuidString)")
            let record = CKRecord(recordType: "ArchivedTaskRecord", recordID: archID)
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
            deleteIDs.append(familyRecordID(name: task.id.uuidString))
        }

        do {
            let db = familyDatabase
            let batchSize = 400
            for start in stride(from: 0, to: savedRecords.count, by: batchSize) {
                let end = min(start + batchSize, savedRecords.count)
                let saveBatch = Array(savedRecords[start..<end])
                let deleteBatch = Array(deleteIDs[start..<end])
                _ = try await db.modifyRecords(saving: saveBatch, deleting: deleteBatch)
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
        let records = await fetchAllRecords(type: "ArchivedTaskRecord", familyCode: familyCode, from: familyDatabase, inZone: familyZoneID)
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

    enum SyncChange {
        case taskApproved(taskName: String, assignedTo: String, reward: Double, hasGift: Bool)
        case taskRejected(taskName: String, assignedTo: String)
        case taskInReview(taskName: String, childName: String)
        case taskAssigned(taskName: String, assignedTo: String, createdBy: String)
        case taskReminded(taskName: String, assignedTo: String)
        case redemptionRequested(description: String, childName: String, coins: Int)
        case redemptionApproved(description: String, childName: String)
        case redemptionRejected(description: String, childName: String, reason: String)
        case redemptionFulfilled(description: String, childName: String)
        case memberAccepted(name: String, appleUserID: String)
        case memberRequested(name: String)
        case pickupRequested(childName: String)
        case pickupAcknowledged(parentName: String)
        case chatReceived(senderName: String, text: String)
    }

    struct SyncResult {
        var newTasks: [SyncedTask] = []
        var changes: [SyncChange] = []
    }

    @discardableResult
    func syncAll(context: ModelContext, familyCode: String, onNewTasks: (([SyncedTask]) -> Void)? = nil) async -> SyncResult {
        guard !familyCode.isEmpty, !syncInProgress else { return SyncResult() }
        syncInProgress = true
        isSyncing = true
        lastSyncError = nil
        defer {
            isSyncing = false
            syncInProgress = false
        }

        var result = SyncResult()

        if familyZoneID != nil {
            let localCount = (try? context.fetch(FetchDescriptor<Item>()))?.count ?? 0
            if localCount == 0 && loadChangeToken() != nil {
                clearChangeToken()
                print("[CloudKit] Local store empty with saved token — forcing full re-sync")
            }
            result = await deltaSyncFamilyZone(context: context, familyCode: familyCode)
        } else {
            result.newTasks = await syncTasks(context: context, familyCode: familyCode)
            await syncRedemptions(context: context, familyCode: familyCode)
            await syncShoppingItems(context: context, familyCode: familyCode)
            await syncAnnualReminders(context: context, familyCode: familyCode)
            await syncProjects(context: context, familyCode: familyCode)
            await syncIdeas(context: context, familyCode: familyCode)
            await syncVotes(context: context, familyCode: familyCode)
            await syncWishListItems(context: context, familyCode: familyCode)
        }

        let memberChanges = await syncMembers(context: context, familyCode: familyCode)
        result.changes.append(contentsOf: memberChanges)
        try? context.save()

        if !result.newTasks.isEmpty {
            onNewTasks?(result.newTasks)
        }
        return result
    }

    private func fetchAllRecords(type: String, familyCode: String, from targetDB: CKDatabase? = nil, inZone zoneID: CKRecordZone.ID? = nil) async -> [CKRecord] {
        let db = targetDB ?? database
        let predicate = NSPredicate(format: "familyCode == %@", familyCode)
        let query = CKQuery(recordType: type, predicate: predicate)
        let maxAttempts = 4

        for attempt in 0..<maxAttempts {
            var all: [CKRecord] = []
            do {
                var (results, cursor) = try await db.records(matching: query, inZoneWith: zoneID)
                all.append(contentsOf: results.compactMap { try? $0.1.get() })

                while let c = cursor {
                    let (more, next) = try await db.records(continuingMatchFrom: c)
                    all.append(contentsOf: more.compactMap { try? $0.1.get() })
                    cursor = next
                }
                print("[CloudKit] FETCH \(type): \(all.count) records for family=\(familyCode)")
                return all
            } catch {
                if attempt < maxAttempts - 1 && isTransientCKError(error) {
                    let delay = retryDelay(for: error, attempt: attempt)
                    print("[CloudKit] FETCH RETRY \(type) attempt \(attempt + 1), waiting \(delay)s: \(error.localizedDescription)")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                lastSyncError = error.localizedDescription
                print("[CloudKit] FETCH ERROR \(type): \(error.localizedDescription)")
                return []
            }
        }
        return []
    }

    @discardableResult
    private func syncTasks(context: ModelContext, familyCode: String) async -> [SyncedTask] {
        let remoteRecords = await fetchAllRecords(type: "TaskRecord", familyCode: familyCode, from: familyDatabase, inZone: familyZoneID)

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
                let remoteArchived = ((record["isArchived"] as? NSNumber)?.intValue ?? 0) == 1
                local.isArchived = local.isMissed ? false : remoteArchived
                local.isRecurring = ((record["isRecurring"] as? NSNumber)?.intValue ?? 0) == 1
                local.giftText = record["giftText"] as? String ?? local.giftText
                local.giftRevealed = ((record["giftRevealed"] as? NSNumber)?.intValue ?? 0) == 1
                let remoteCreatedBy = record["createdBy"] as? String ?? ""
                if !remoteCreatedBy.isEmpty { local.createdBy = remoteCreatedBy }
                let remoteCreatedByID = record["createdByID"] as? String ?? ""
                if !remoteCreatedByID.isEmpty { local.createdByID = remoteCreatedByID }
                let remoteTransport = record["transportType"] as? String ?? ""
                if !remoteTransport.isEmpty { local.transportType = remoteTransport }
                let remoteProjectId = record["projectId"] as? String ?? ""
                if !remoteProjectId.isEmpty { local.projectId = remoteProjectId }
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
                    createdByID: record["createdByID"] as? String ?? "",
                    transportType: record["transportType"] as? String ?? "none",
                    projectId: record["projectId"] as? String ?? ""
                )
                item.isArchived = status == "missed" ? false : ((record["isArchived"] as? NSNumber)?.intValue ?? 0) == 1
                item.giftRevealed = ((record["giftRevealed"] as? NSNumber)?.intValue ?? 0) == 1
                context.insert(item)

                if status == "open" {
                    let createdBy = record["createdBy"] as? String ?? ""
                    newTasks.append(SyncedTask(id: uuid, name: name, targetDate: targetDate, assignedTo: assignedTo, createdBy: createdBy))
                }
            }
        }

        if !remoteRecords.isEmpty {
            for task in localTasks where !remoteIDs.contains(task.id.uuidString) {
                context.delete(task)
            }
        }

        return newTasks
    }

    @discardableResult
    private func syncMembers(context: ModelContext, familyCode: String) async -> [SyncChange] {
        let remoteRecords = await fetchAllRecords(type: "MemberRecord", familyCode: familyCode)

        let descriptor = FetchDescriptor<FamilyMember>()
        let localMembers = (try? context.fetch(descriptor)) ?? []
        let localByID = Dictionary(uniqueKeysWithValues: localMembers.map { ($0.id.uuidString, $0) })
        let remoteIDs = Set(remoteRecords.map { $0.recordID.recordName })
        var changes: [SyncChange] = []

        for record in remoteRecords {
            let idStr = record.recordID.recordName
            let remoteAvatar = record["avatar"] as? String ?? "star.fill"
            cacheAvatarPhotoIfNeeded(avatar: remoteAvatar, record: record)
            let remoteAccepted = ((record["isAccepted"] as? NSNumber)?.intValue ?? 1) == 1
            let remotePickupAt = record["lastPickupAt"] as? Date
            let remoteAckAt = record["lastPickupAckAt"] as? Date
            let remoteAckBy = record["lastPickupAckBy"] as? String ?? ""

            if let local = localByID[idStr] {
                let wasAccepted = local.isAccepted
                let oldPickup = local.lastPickupAt
                let oldAck = local.lastPickupAckAt

                local.name = record["name"] as? String ?? local.name
                local.memberRole = record["memberRole"] as? String ?? local.memberRole
                local.avatar = remoteAvatar
                local.totalEarned = (record["totalEarned"] as? NSNumber)?.doubleValue ?? local.totalEarned
                local.appleUserID = record["appleUserID"] as? String ?? local.appleUserID
                local.isAccepted = remoteAccepted
                if let rp = remotePickupAt { local.lastPickupAt = rp }
                if let ra = remoteAckAt { local.lastPickupAckAt = ra }
                if !remoteAckBy.isEmpty { local.lastPickupAckBy = remoteAckBy }

                if !wasAccepted && remoteAccepted {
                    changes.append(.memberAccepted(name: local.name, appleUserID: local.appleUserID))
                }
                if let rp = remotePickupAt, rp != oldPickup, rp.timeIntervalSinceNow > -600 {
                    changes.append(.pickupRequested(childName: local.name))
                }
                if let ra = remoteAckAt, ra != oldAck, ra.timeIntervalSinceNow > -600 {
                    changes.append(.pickupAcknowledged(parentName: remoteAckBy))
                }
            } else if let uuid = UUID(uuidString: idStr) {
                let name = record["name"] as? String ?? ""
                let member = FamilyMember(
                    id: uuid,
                    name: name,
                    memberRole: record["memberRole"] as? String ?? "child",
                    avatar: remoteAvatar,
                    isAccepted: remoteAccepted,
                    appleUserID: record["appleUserID"] as? String ?? ""
                )
                member.totalEarned = (record["totalEarned"] as? NSNumber)?.doubleValue ?? 0
                if let rp = remotePickupAt { member.lastPickupAt = rp }
                if let ra = remoteAckAt { member.lastPickupAckAt = ra }
                member.lastPickupAckBy = remoteAckBy
                context.insert(member)

                if !remoteAccepted {
                    changes.append(.memberRequested(name: name))
                }
            }
        }

        for member in localMembers where !remoteIDs.contains(member.id.uuidString) {
            context.delete(member)
        }
        return changes
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

        let recordID = familyRecordID(name: id)
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
        return await saveRecord(record, to: familyDatabase)
    }

    private func syncRedemptions(context: ModelContext, familyCode: String) async {
        let remoteRecords = await fetchAllRecords(type: "RedemptionRecord", familyCode: familyCode, from: familyDatabase, inZone: familyZoneID)

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

        if !remoteRecords.isEmpty {
            for item in local where !remoteIDs.contains(item.id.uuidString) {
                context.delete(item)
            }
        }
    }

    // MARK: - Chat Messages

    func pushChatMessage(_ message: ChatMessage, familyCode: String) async -> Bool {
        guard !familyCode.isEmpty else { return false }
        let recordID = familyRecordID(name: message.id.uuidString)
        let record = CKRecord(recordType: "ChatRecord", recordID: recordID)
        record["familyCode"] = familyCode
        record["senderName"] = message.senderName
        record["senderAvatar"] = message.senderAvatar
        record["senderAppleUserID"] = message.senderAppleUserID
        record["text"] = message.text
        record["reactions"] = message.reactions
        record["sentAt"] = message.sentAt as NSDate
        record["attachmentName"] = message.attachmentName
        record["attachmentType"] = message.attachmentType

        if let data = message.attachmentData {
            let ext = message.attachmentType == "image" ? "jpg" : message.attachmentName.components(separatedBy: ".").last ?? "dat"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(message.id.uuidString + "." + ext)
            do {
                try data.write(to: tempURL)
                record["attachment"] = CKAsset(fileURL: tempURL)
            } catch {
                print("[CK] Failed to write attachment temp file: \(error)")
            }
        }

        return await saveRecord(record, to: familyDatabase)
    }

    private func applyChatRecord(_ record: CKRecord, context: ModelContext) -> SyncChange? {
        let idStr = record.recordID.recordName
        guard let uuid = UUID(uuidString: idStr) else { return nil }

        let attachmentData: Data? = {
            let asset = (record["attachment"] as? CKAsset) ?? (record["photo"] as? CKAsset)
            guard let fileURL = asset?.fileURL else { return nil }
            return try? Data(contentsOf: fileURL)
        }()
        let attachmentName = record["attachmentName"] as? String ?? ""
        let attachmentType = record["attachmentType"] as? String ?? "image"

        let descriptor = FetchDescriptor<ChatMessage>()
        let all = (try? context.fetch(descriptor)) ?? []

        if let existing = all.first(where: { $0.id == uuid }) {
            existing.text = record["text"] as? String ?? existing.text
            existing.reactions = record["reactions"] as? String ?? existing.reactions
            if let attachmentData, existing.attachmentData == nil {
                existing.attachmentData = attachmentData
                existing.attachmentName = attachmentName
                existing.attachmentType = attachmentType
            }
            return nil
        } else {
            let msg = ChatMessage(
                id: uuid,
                senderName: record["senderName"] as? String ?? "",
                senderAvatar: record["senderAvatar"] as? String ?? "",
                senderAppleUserID: record["senderAppleUserID"] as? String ?? "",
                text: record["text"] as? String ?? "",
                sentAt: record["sentAt"] as? Date ?? Date(),
                attachmentData: attachmentData,
                attachmentName: attachmentName,
                attachmentType: attachmentType
            )
            msg.reactions = record["reactions"] as? String ?? ""
            context.insert(msg)
            return .chatReceived(senderName: msg.senderName, text: msg.text)
        }
    }

    func clearChatAttachments(familyCode: String, context: ModelContext) async -> Int {
        let descriptor = FetchDescriptor<ChatMessage>()
        let all = (try? context.fetch(descriptor)) ?? []
        var cleared = 0

        for msg in all where msg.attachmentData != nil {
            msg.attachmentData = nil
            msg.attachmentName = ""
            msg.attachmentType = "image"
            cleared += 1

            let recordID = familyRecordID(name: msg.id.uuidString)
            let record = CKRecord(recordType: "ChatRecord", recordID: recordID)
            record["familyCode"] = familyCode
            record["senderName"] = msg.senderName
            record["senderAvatar"] = msg.senderAvatar
            record["senderAppleUserID"] = msg.senderAppleUserID
            record["text"] = msg.text
            record["reactions"] = msg.reactions
            record["sentAt"] = msg.sentAt as NSDate
            record["attachmentName"] = ""
            record["attachmentType"] = "image"
            _ = await saveRecord(record, to: familyDatabase)
        }

        return cleared
    }

    // MARK: - Shopping Items

    private static let pendingShoppingPushesKey = "pendingShoppingPushes"

    struct ShoppingSnapshot {
        let id: String
        let name: String
        let addedBy: String
        let isBought: Bool
        let createdAt: Date

        init(_ item: ShoppingItem) {
            self.id = item.id.uuidString
            self.name = item.name
            self.addedBy = item.addedBy
            self.isBought = item.isBought
            self.createdAt = item.createdAt
        }
    }

    func pushShoppingItem(_ item: ShoppingItem, familyCode: String) async -> Bool {
        await pushShoppingSnapshot(ShoppingSnapshot(item), familyCode: familyCode)
    }

    func pushShoppingSnapshot(_ snap: ShoppingSnapshot, familyCode: String) async -> Bool {
        guard !familyCode.isEmpty else { return false }

        if familyZoneID != nil {
            let recordID = familyRecordID(name: snap.id)
            let record = CKRecord(recordType: "ShoppingRecord", recordID: recordID)
            record["familyCode"] = familyCode
            record["itemID"] = snap.id
            record["name"] = snap.name
            record["addedBy"] = snap.addedBy
            record["isBought"] = snap.isBought ? 1 : 0
            record["createdAt"] = snap.createdAt as NSDate
            record["updatedAt"] = Date() as NSDate
            print("[CloudKit] Shopping push (zone): itemID=\(snap.id) isBought=\(snap.isBought)")
            return await saveRecord(record, to: familyDatabase)
        }

        addPendingPush(snap.id)
        let newRecordName = UUID().uuidString
        let record = CKRecord(recordType: "ShoppingRecord", recordID: CKRecord.ID(recordName: newRecordName))
        record["familyCode"] = familyCode
        record["itemID"] = snap.id
        record["name"] = snap.name
        record["addedBy"] = snap.addedBy
        record["isBought"] = snap.isBought ? 1 : 0
        record["createdAt"] = snap.createdAt as NSDate
        record["updatedAt"] = Date() as NSDate
        print("[CloudKit] Shopping push (public): itemID=\(snap.id) isBought=\(snap.isBought)")
        let success = await saveRecord(record)
        if success { removePendingPush(snap.id) }
        return success
    }

    private func addPendingPush(_ id: String) {
        var set = Set(UserDefaults.standard.stringArray(forKey: Self.pendingShoppingPushesKey) ?? [])
        set.insert(id)
        UserDefaults.standard.set(Array(set), forKey: Self.pendingShoppingPushesKey)
    }

    private func removePendingPush(_ id: String) {
        var set = Set(UserDefaults.standard.stringArray(forKey: Self.pendingShoppingPushesKey) ?? [])
        set.remove(id)
        UserDefaults.standard.set(Array(set), forKey: Self.pendingShoppingPushesKey)
    }

    private static let pendingShoppingDeletesKey = "pendingShoppingDeletes"

    func deleteShoppingItem(id: UUID, familyCode: String) async {
        let idStr = id.uuidString

        if familyZoneID != nil {
            let recordID = familyRecordID(name: idStr)
            do {
                try await familyDatabase.deleteRecord(withID: recordID)
            } catch {
                lastSyncError = error.localizedDescription
            }
            return
        }

        var pending = Set(UserDefaults.standard.stringArray(forKey: Self.pendingShoppingDeletesKey) ?? [])
        pending.insert(idStr)
        UserDefaults.standard.set(Array(pending), forKey: Self.pendingShoppingDeletesKey)

        let predicate = NSPredicate(format: "familyCode == %@ AND itemID == %@", familyCode, idStr)
        let query = CKQuery(recordType: "ShoppingRecord", predicate: predicate)
        do {
            let (results, _) = try await database.records(matching: query)
            for (recordID, _) in results {
                _ = try? await database.deleteRecord(withID: recordID)
            }
        } catch {
            lastSyncError = error.localizedDescription
            print("[CloudKit] Shopping delete failed: \(error.localizedDescription)")
        }

        let legacyID = CKRecord.ID(recordName: idStr)
        _ = try? await database.deleteRecord(withID: legacyID)

        pending.remove(idStr)
        UserDefaults.standard.set(Array(pending), forKey: Self.pendingShoppingDeletesKey)
    }

    func syncShoppingOnly(context: ModelContext, familyCode: String) async {
        guard !familyCode.isEmpty else { return }
        await syncShoppingItems(context: context, familyCode: familyCode)
        try? context.save()
    }

    private func syncShoppingItems(context: ModelContext, familyCode: String) async {
        if familyZoneID != nil {
            await syncShoppingItemsFromZone(context: context, familyCode: familyCode)
        } else {
            await syncShoppingItemsFromPublic(context: context, familyCode: familyCode)
        }
    }

    private func syncShoppingItemsFromZone(context: ModelContext, familyCode: String) async {
        let remoteRecords = await fetchAllRecords(type: "ShoppingRecord", familyCode: familyCode, from: familyDatabase, inZone: familyZoneID)

        let descriptor = FetchDescriptor<ShoppingItem>()
        let local = (try? context.fetch(descriptor)) ?? []
        let localByID = Dictionary(uniqueKeysWithValues: local.map { ($0.id.uuidString, $0) })
        let remoteIDs = Set(remoteRecords.map { $0.recordID.recordName })

        for record in remoteRecords {
            let idStr = record.recordID.recordName
            let bought = record["isBought"]
            let isBoughtVal: Bool
            if let num = bought as? NSNumber { isBoughtVal = num.intValue == 1 }
            else if let int = bought as? Int { isBoughtVal = int == 1 }
            else { isBoughtVal = false }

            if let existing = localByID[idStr] {
                existing.name = record["name"] as? String ?? existing.name
                existing.addedBy = record["addedBy"] as? String ?? existing.addedBy
                existing.isBought = isBoughtVal
                existing.createdAt = record["createdAt"] as? Date ?? existing.createdAt
            } else if let uuid = UUID(uuidString: idStr) {
                let item = ShoppingItem(
                    id: uuid,
                    name: record["name"] as? String ?? "",
                    addedBy: record["addedBy"] as? String ?? "",
                    isBought: isBoughtVal,
                    createdAt: record["createdAt"] as? Date ?? Date()
                )
                context.insert(item)
            }
        }

        if !remoteRecords.isEmpty {
            for item in local where !remoteIDs.contains(item.id.uuidString) {
                context.delete(item)
            }
        }
    }

    private func syncShoppingItemsFromPublic(context: ModelContext, familyCode: String) async {
        let remoteRecords = await fetchAllRecords(type: "ShoppingRecord", familyCode: familyCode)
        let pendingDeletes = Set(UserDefaults.standard.stringArray(forKey: Self.pendingShoppingDeletesKey) ?? [])
        let pendingPushes = Set(UserDefaults.standard.stringArray(forKey: Self.pendingShoppingPushesKey) ?? [])

        var latestByItemID: [String: CKRecord] = [:]
        var duplicateRecordIDs: [CKRecord.ID] = []

        for record in remoteRecords {
            let itemID = record["itemID"] as? String ?? record.recordID.recordName
            let recordTime = record["updatedAt"] as? Date ?? record.creationDate ?? .distantPast

            if let existing = latestByItemID[itemID] {
                let existingTime = existing["updatedAt"] as? Date ?? existing.creationDate ?? .distantPast
                if recordTime > existingTime {
                    duplicateRecordIDs.append(existing.recordID)
                    latestByItemID[itemID] = record
                } else {
                    duplicateRecordIDs.append(record.recordID)
                }
            } else {
                latestByItemID[itemID] = record
            }
        }

        for dupID in duplicateRecordIDs {
            _ = try? await database.deleteRecord(withID: dupID)
        }

        let descriptor = FetchDescriptor<ShoppingItem>()
        let local = (try? context.fetch(descriptor)) ?? []
        let localByID = Dictionary(uniqueKeysWithValues: local.map { ($0.id.uuidString, $0) })
        let remoteItemIDs = Set(latestByItemID.keys)

        for (itemID, record) in latestByItemID {
            if pendingDeletes.contains(itemID) { continue }
            if let existing = localByID[itemID] {
                if !pendingPushes.contains(itemID) {
                    existing.name = record["name"] as? String ?? existing.name
                    existing.addedBy = record["addedBy"] as? String ?? existing.addedBy
                    let bought = record["isBought"]
                    if let num = bought as? NSNumber {
                        existing.isBought = num.intValue == 1
                    } else if let int = bought as? Int {
                        existing.isBought = int == 1
                    }
                    existing.createdAt = record["createdAt"] as? Date ?? existing.createdAt
                }
            } else if let uuid = UUID(uuidString: itemID) {
                let boughtVal = record["isBought"]
                let isBought: Bool
                if let num = boughtVal as? NSNumber {
                    isBought = num.intValue == 1
                } else if let int = boughtVal as? Int {
                    isBought = int == 1
                } else {
                    isBought = false
                }
                let item = ShoppingItem(
                    id: uuid,
                    name: record["name"] as? String ?? "",
                    addedBy: record["addedBy"] as? String ?? "",
                    isBought: isBought,
                    createdAt: record["createdAt"] as? Date ?? Date()
                )
                context.insert(item)
            }
        }

        for item in local {
            let idStr = item.id.uuidString
            if pendingPushes.contains(idStr) { continue }
            if !remoteItemIDs.contains(idStr) || pendingDeletes.contains(idStr) {
                context.delete(item)
            }
        }
    }

    // MARK: - Wish List

    struct WishListSnapshot {
        let id: String
        let name: String
        let ownerAppleUserID: String
        let ownerName: String
        let createdAt: Date

        init(_ item: WishListItem) {
            self.id = item.id.uuidString
            self.name = item.name
            self.ownerAppleUserID = item.ownerAppleUserID
            self.ownerName = item.ownerName
            self.createdAt = item.createdAt
        }
    }

    func pushWishListItem(_ item: WishListItem, familyCode: String) async -> Bool {
        await pushWishListSnapshot(WishListSnapshot(item), familyCode: familyCode)
    }

    func pushWishListSnapshot(_ snap: WishListSnapshot, familyCode: String) async -> Bool {
        guard !familyCode.isEmpty else { return false }

        if familyZoneID != nil {
            let recordID = familyRecordID(name: snap.id)
            let record = CKRecord(recordType: "WishListRecord", recordID: recordID)
            record["familyCode"] = familyCode
            record["itemID"] = snap.id
            record["name"] = snap.name
            record["ownerAppleUserID"] = snap.ownerAppleUserID
            record["ownerName"] = snap.ownerName
            record["createdAt"] = snap.createdAt as NSDate
            record["updatedAt"] = Date() as NSDate
            return await saveRecord(record, to: familyDatabase)
        }

        let newRecordName = UUID().uuidString
        let record = CKRecord(recordType: "WishListRecord", recordID: CKRecord.ID(recordName: newRecordName))
        record["familyCode"] = familyCode
        record["itemID"] = snap.id
        record["name"] = snap.name
        record["ownerAppleUserID"] = snap.ownerAppleUserID
        record["ownerName"] = snap.ownerName
        record["createdAt"] = snap.createdAt as NSDate
        record["updatedAt"] = Date() as NSDate
        return await saveRecord(record)
    }

    func deleteWishListItem(id: UUID, familyCode: String) async {
        let idStr = id.uuidString

        if familyZoneID != nil {
            let recordID = familyRecordID(name: idStr)
            do {
                try await familyDatabase.deleteRecord(withID: recordID)
            } catch {
                lastSyncError = error.localizedDescription
            }
            return
        }

        let predicate = NSPredicate(format: "familyCode == %@ AND itemID == %@", familyCode, idStr)
        let query = CKQuery(recordType: "WishListRecord", predicate: predicate)
        do {
            let (results, _) = try await database.records(matching: query)
            for (recordID, _) in results {
                _ = try? await database.deleteRecord(withID: recordID)
            }
        } catch {
            lastSyncError = error.localizedDescription
            print("[CloudKit] WishList delete failed: \(error.localizedDescription)")
        }

        let legacyID = CKRecord.ID(recordName: idStr)
        _ = try? await database.deleteRecord(withID: legacyID)
    }

    private func syncWishListItems(context: ModelContext, familyCode: String) async {
        if familyZoneID != nil {
            await syncWishListFromZone(context: context, familyCode: familyCode)
        } else {
            await syncWishListFromPublic(context: context, familyCode: familyCode)
        }
    }

    private func syncWishListFromZone(context: ModelContext, familyCode: String) async {
        let remoteRecords = await fetchAllRecords(type: "WishListRecord", familyCode: familyCode, from: familyDatabase, inZone: familyZoneID)

        let descriptor = FetchDescriptor<WishListItem>()
        let local = (try? context.fetch(descriptor)) ?? []
        let localByID = Dictionary(uniqueKeysWithValues: local.map { ($0.id.uuidString, $0) })
        let remoteIDs = Set(remoteRecords.map { $0.recordID.recordName })

        for record in remoteRecords {
            let idStr = record.recordID.recordName
            if let existing = localByID[idStr] {
                existing.name = record["name"] as? String ?? existing.name
                existing.ownerAppleUserID = record["ownerAppleUserID"] as? String ?? existing.ownerAppleUserID
                existing.ownerName = record["ownerName"] as? String ?? existing.ownerName
                existing.createdAt = record["createdAt"] as? Date ?? existing.createdAt
            } else if let uuid = UUID(uuidString: idStr) {
                let item = WishListItem(
                    id: uuid,
                    name: record["name"] as? String ?? "",
                    ownerAppleUserID: record["ownerAppleUserID"] as? String ?? "",
                    ownerName: record["ownerName"] as? String ?? "",
                    createdAt: record["createdAt"] as? Date ?? Date()
                )
                context.insert(item)
            }
        }

        if !remoteRecords.isEmpty {
            for item in local where !remoteIDs.contains(item.id.uuidString) {
                context.delete(item)
            }
        }
    }

    private func syncWishListFromPublic(context: ModelContext, familyCode: String) async {
        let remoteRecords = await fetchAllRecords(type: "WishListRecord", familyCode: familyCode)

        var latestByItemID: [String: CKRecord] = [:]
        var duplicateRecordIDs: [CKRecord.ID] = []

        for record in remoteRecords {
            let itemID = record["itemID"] as? String ?? record.recordID.recordName
            let recordTime = record["updatedAt"] as? Date ?? record.creationDate ?? .distantPast
            if let existing = latestByItemID[itemID] {
                let existingTime = existing["updatedAt"] as? Date ?? existing.creationDate ?? .distantPast
                if recordTime > existingTime {
                    duplicateRecordIDs.append(existing.recordID)
                    latestByItemID[itemID] = record
                } else {
                    duplicateRecordIDs.append(record.recordID)
                }
            } else {
                latestByItemID[itemID] = record
            }
        }

        for dupID in duplicateRecordIDs {
            _ = try? await database.deleteRecord(withID: dupID)
        }

        let descriptor = FetchDescriptor<WishListItem>()
        let local = (try? context.fetch(descriptor)) ?? []
        let localByID = Dictionary(uniqueKeysWithValues: local.map { ($0.id.uuidString, $0) })
        let remoteItemIDs = Set(latestByItemID.keys)

        for (itemID, record) in latestByItemID {
            if let existing = localByID[itemID] {
                existing.name = record["name"] as? String ?? existing.name
                existing.ownerAppleUserID = record["ownerAppleUserID"] as? String ?? existing.ownerAppleUserID
                existing.ownerName = record["ownerName"] as? String ?? existing.ownerName
                existing.createdAt = record["createdAt"] as? Date ?? existing.createdAt
            } else if let uuid = UUID(uuidString: itemID) {
                let item = WishListItem(
                    id: uuid,
                    name: record["name"] as? String ?? "",
                    ownerAppleUserID: record["ownerAppleUserID"] as? String ?? "",
                    ownerName: record["ownerName"] as? String ?? "",
                    createdAt: record["createdAt"] as? Date ?? Date()
                )
                context.insert(item)
            }
        }

        for item in local where !remoteItemIDs.contains(item.id.uuidString) {
            context.delete(item)
        }
    }

    private func applyWishListRecord(_ record: CKRecord, context: ModelContext) {
        let idStr = record.recordID.recordName
        guard let uuid = UUID(uuidString: idStr) else { return }

        let descriptor = FetchDescriptor<WishListItem>()
        let all = (try? context.fetch(descriptor)) ?? []

        if let existing = all.first(where: { $0.id == uuid }) {
            existing.name = record["name"] as? String ?? existing.name
            existing.ownerAppleUserID = record["ownerAppleUserID"] as? String ?? existing.ownerAppleUserID
            existing.ownerName = record["ownerName"] as? String ?? existing.ownerName
            existing.createdAt = record["createdAt"] as? Date ?? existing.createdAt
        } else {
            let item = WishListItem(
                id: uuid,
                name: record["name"] as? String ?? "",
                ownerAppleUserID: record["ownerAppleUserID"] as? String ?? "",
                ownerName: record["ownerName"] as? String ?? "",
                createdAt: record["createdAt"] as? Date ?? Date()
            )
            context.insert(item)
        }
    }

    // MARK: - Annual Reminders

    @discardableResult
    func pushAnnualReminder(_ reminder: AnnualReminder, familyCode: String) async -> Bool {
        guard !familyCode.isEmpty else { return false }
        let recordID = familyRecordID(name: reminder.id.uuidString)
        let record = CKRecord(recordType: "AnnualReminderRecord", recordID: recordID)
        record["familyCode"] = familyCode
        record["name"] = reminder.name
        record["category"] = reminder.category
        record["dueDate"] = reminder.dueDate as NSDate
        record["repeatYearly"] = NSNumber(value: reminder.repeatYearly ? 1 : 0)
        record["repeatFrequency"] = reminder.repeatFrequency
        record["remindDaysBefore"] = reminder.remindDaysBefore
        record["notes"] = reminder.notes
        record["isDone"] = NSNumber(value: reminder.isDone ? 1 : 0)
        record["createdAt"] = reminder.createdAt as NSDate
        return await saveRecord(record, to: familyDatabase)
    }

    func deleteAnnualReminder(id: UUID) async {
        let recordID = familyRecordID(name: id.uuidString)
        do {
            try await familyDatabase.deleteRecord(withID: recordID)
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    func syncAnnualReminders(context: ModelContext, familyCode: String) async {
        let remoteRecords = await fetchAllRecords(
            type: "AnnualReminderRecord", familyCode: familyCode,
            from: familyDatabase, inZone: familyZoneID
        )
        let descriptor = FetchDescriptor<AnnualReminder>()
        let local = (try? context.fetch(descriptor)) ?? []
        let localByID = Dictionary(uniqueKeysWithValues: local.map { ($0.id.uuidString, $0) })
        let remoteIDs = Set(remoteRecords.map { $0.recordID.recordName })

        for record in remoteRecords {
            let idStr = record.recordID.recordName
            if let existing = localByID[idStr] {
                existing.name = record["name"] as? String ?? existing.name
                existing.category = record["category"] as? String ?? existing.category
                existing.dueDate = record["dueDate"] as? Date ?? existing.dueDate
                existing.repeatYearly = ((record["repeatYearly"] as? NSNumber)?.intValue ?? 1) == 1
                let remoteFreq = record["repeatFrequency"] as? String ?? ""
                if !remoteFreq.isEmpty { existing.repeatFrequency = remoteFreq }
                existing.remindDaysBefore = record["remindDaysBefore"] as? String ?? existing.remindDaysBefore
                existing.notes = record["notes"] as? String ?? existing.notes
                existing.isDone = ((record["isDone"] as? NSNumber)?.intValue ?? 0) == 1
            } else if let uuid = UUID(uuidString: idStr) {
                let item = AnnualReminder(
                    id: uuid,
                    name: record["name"] as? String ?? "",
                    category: record["category"] as? String ?? "Home",
                    dueDate: record["dueDate"] as? Date ?? Date(),
                    repeatYearly: ((record["repeatYearly"] as? NSNumber)?.intValue ?? 1) == 1,
                    repeatFrequency: record["repeatFrequency"] as? String ?? "Yearly",
                    remindDaysBefore: record["remindDaysBefore"] as? String ?? "[30,14,7]",
                    notes: record["notes"] as? String ?? "",
                    isDone: ((record["isDone"] as? NSNumber)?.intValue ?? 0) == 1
                )
                context.insert(item)
            }
        }

        if !remoteRecords.isEmpty {
            for item in local where !remoteIDs.contains(item.id.uuidString) {
                context.delete(item)
            }
        }
    }

    // MARK: - Family Projects

    @discardableResult
    func pushProject(_ project: FamilyProject, familyCode: String) async -> Bool {
        guard !familyCode.isEmpty else { return false }
        let recordID = familyRecordID(name: project.id.uuidString)
        let record = CKRecord(recordType: "ProjectRecord", recordID: recordID)
        record["familyCode"] = familyCode
        record["name"] = project.name
        record["descriptionText"] = project.descriptionText
        record["category"] = project.category
        record["status"] = project.status
        record["createdBy"] = project.createdBy
        if let target = project.targetDate {
            record["targetDate"] = target as NSDate
        }
        record["createdAt"] = project.createdAt as NSDate
        return await saveRecord(record, to: familyDatabase)
    }

    func deleteRemoteProject(_ projectID: UUID) async {
        let recordID = familyRecordID(name: projectID.uuidString)
        do {
            try await familyDatabase.deleteRecord(withID: recordID)
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    @discardableResult
    func pushIdea(_ idea: ProjectIdea, familyCode: String) async -> Bool {
        guard !familyCode.isEmpty else { return false }
        let recordID = familyRecordID(name: idea.id.uuidString)
        let record = CKRecord(recordType: "ProjectIdeaRecord", recordID: recordID)
        record["familyCode"] = familyCode
        record["projectId"] = idea.projectId
        record["text"] = idea.text
        record["submittedBy"] = idea.submittedBy
        record["createdAt"] = idea.createdAt as NSDate
        return await saveRecord(record, to: familyDatabase)
    }

    func deleteRemoteIdea(_ ideaID: UUID) async {
        let recordID = familyRecordID(name: ideaID.uuidString)
        do {
            try await familyDatabase.deleteRecord(withID: recordID)
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    @discardableResult
    func pushVote(_ vote: ProjectVote, familyCode: String) async -> Bool {
        guard !familyCode.isEmpty else { return false }
        let recordID = familyRecordID(name: vote.id.uuidString)
        let record = CKRecord(recordType: "ProjectVoteRecord", recordID: recordID)
        record["familyCode"] = familyCode
        record["ideaId"] = vote.ideaId
        record["memberName"] = vote.memberName
        record["isUpvote"] = NSNumber(value: vote.isUpvote ? 1 : 0)
        return await saveRecord(record, to: familyDatabase)
    }

    func deleteRemoteVote(_ voteID: UUID) async {
        let recordID = familyRecordID(name: voteID.uuidString)
        do {
            try await familyDatabase.deleteRecord(withID: recordID)
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    func syncProjects(context: ModelContext, familyCode: String) async {
        let remoteRecords = await fetchAllRecords(type: "ProjectRecord", familyCode: familyCode, from: familyDatabase, inZone: familyZoneID)
        let descriptor = FetchDescriptor<FamilyProject>()
        let local = (try? context.fetch(descriptor)) ?? []
        let localByID = Dictionary(uniqueKeysWithValues: local.map { ($0.id.uuidString, $0) })
        let remoteIDs = Set(remoteRecords.map { $0.recordID.recordName })

        for record in remoteRecords {
            let idStr = record.recordID.recordName
            if let existing = localByID[idStr] {
                existing.name = record["name"] as? String ?? existing.name
                existing.descriptionText = record["descriptionText"] as? String ?? existing.descriptionText
                existing.category = record["category"] as? String ?? existing.category
                existing.status = record["status"] as? String ?? existing.status
                existing.createdBy = record["createdBy"] as? String ?? existing.createdBy
                existing.targetDate = record["targetDate"] as? Date
                existing.createdAt = record["createdAt"] as? Date ?? existing.createdAt
            } else if let uuid = UUID(uuidString: idStr) {
                let project = FamilyProject(
                    id: uuid,
                    name: record["name"] as? String ?? "",
                    descriptionText: record["descriptionText"] as? String ?? "",
                    category: record["category"] as? String ?? "Home",
                    status: record["status"] as? String ?? "ideating",
                    createdBy: record["createdBy"] as? String ?? "",
                    targetDate: record["targetDate"] as? Date
                )
                project.createdAt = record["createdAt"] as? Date ?? Date()
                context.insert(project)
            }
        }

        if !remoteRecords.isEmpty {
            for item in local where !remoteIDs.contains(item.id.uuidString) {
                context.delete(item)
            }
        }
    }

    func syncIdeas(context: ModelContext, familyCode: String) async {
        let remoteRecords = await fetchAllRecords(type: "ProjectIdeaRecord", familyCode: familyCode, from: familyDatabase, inZone: familyZoneID)
        let descriptor = FetchDescriptor<ProjectIdea>()
        let local = (try? context.fetch(descriptor)) ?? []
        let localByID = Dictionary(uniqueKeysWithValues: local.map { ($0.id.uuidString, $0) })
        let remoteIDs = Set(remoteRecords.map { $0.recordID.recordName })

        for record in remoteRecords {
            let idStr = record.recordID.recordName
            if let existing = localByID[idStr] {
                existing.text = record["text"] as? String ?? existing.text
                existing.submittedBy = record["submittedBy"] as? String ?? existing.submittedBy
                existing.projectId = record["projectId"] as? String ?? existing.projectId
            } else if let uuid = UUID(uuidString: idStr) {
                let idea = ProjectIdea(
                    id: uuid,
                    projectId: record["projectId"] as? String ?? "",
                    text: record["text"] as? String ?? "",
                    submittedBy: record["submittedBy"] as? String ?? ""
                )
                idea.createdAt = record["createdAt"] as? Date ?? Date()
                context.insert(idea)
            }
        }

        if !remoteRecords.isEmpty {
            for item in local where !remoteIDs.contains(item.id.uuidString) {
                context.delete(item)
            }
        }
    }

    func syncVotes(context: ModelContext, familyCode: String) async {
        let remoteRecords = await fetchAllRecords(type: "ProjectVoteRecord", familyCode: familyCode, from: familyDatabase, inZone: familyZoneID)
        let descriptor = FetchDescriptor<ProjectVote>()
        let local = (try? context.fetch(descriptor)) ?? []
        let localByID = Dictionary(uniqueKeysWithValues: local.map { ($0.id.uuidString, $0) })
        let remoteIDs = Set(remoteRecords.map { $0.recordID.recordName })

        for record in remoteRecords {
            let idStr = record.recordID.recordName
            if let existing = localByID[idStr] {
                existing.ideaId = record["ideaId"] as? String ?? existing.ideaId
                existing.memberName = record["memberName"] as? String ?? existing.memberName
                existing.isUpvote = ((record["isUpvote"] as? NSNumber)?.intValue ?? 1) == 1
            } else if let uuid = UUID(uuidString: idStr) {
                let vote = ProjectVote(
                    id: uuid,
                    ideaId: record["ideaId"] as? String ?? "",
                    memberName: record["memberName"] as? String ?? "",
                    isUpvote: ((record["isUpvote"] as? NSNumber)?.intValue ?? 1) == 1
                )
                context.insert(vote)
            }
        }

        if !remoteRecords.isEmpty {
            for item in local where !remoteIDs.contains(item.id.uuidString) {
                context.delete(item)
            }
        }
    }

    private func applyProjectRecord(_ record: CKRecord, context: ModelContext) {
        let idStr = record.recordID.recordName
        guard let uuid = UUID(uuidString: idStr) else { return }
        let descriptor = FetchDescriptor<FamilyProject>()
        let all = (try? context.fetch(descriptor)) ?? []

        if let existing = all.first(where: { $0.id == uuid }) {
            existing.name = record["name"] as? String ?? existing.name
            existing.descriptionText = record["descriptionText"] as? String ?? existing.descriptionText
            existing.category = record["category"] as? String ?? existing.category
            existing.status = record["status"] as? String ?? existing.status
            existing.createdBy = record["createdBy"] as? String ?? existing.createdBy
            existing.targetDate = record["targetDate"] as? Date
        } else {
            let project = FamilyProject(
                id: uuid,
                name: record["name"] as? String ?? "",
                descriptionText: record["descriptionText"] as? String ?? "",
                category: record["category"] as? String ?? "Home",
                status: record["status"] as? String ?? "ideating",
                createdBy: record["createdBy"] as? String ?? "",
                targetDate: record["targetDate"] as? Date
            )
            project.createdAt = record["createdAt"] as? Date ?? Date()
            context.insert(project)
        }
    }

    private func applyIdeaRecord(_ record: CKRecord, context: ModelContext) {
        let idStr = record.recordID.recordName
        guard let uuid = UUID(uuidString: idStr) else { return }
        let descriptor = FetchDescriptor<ProjectIdea>()
        let all = (try? context.fetch(descriptor)) ?? []

        if let existing = all.first(where: { $0.id == uuid }) {
            existing.text = record["text"] as? String ?? existing.text
            existing.submittedBy = record["submittedBy"] as? String ?? existing.submittedBy
            existing.projectId = record["projectId"] as? String ?? existing.projectId
        } else {
            let idea = ProjectIdea(
                id: uuid,
                projectId: record["projectId"] as? String ?? "",
                text: record["text"] as? String ?? "",
                submittedBy: record["submittedBy"] as? String ?? ""
            )
            idea.createdAt = record["createdAt"] as? Date ?? Date()
            context.insert(idea)
        }
    }

    private func applyVoteRecord(_ record: CKRecord, context: ModelContext) {
        let idStr = record.recordID.recordName
        guard let uuid = UUID(uuidString: idStr) else { return }
        let descriptor = FetchDescriptor<ProjectVote>()
        let all = (try? context.fetch(descriptor)) ?? []

        if let existing = all.first(where: { $0.id == uuid }) {
            existing.isUpvote = ((record["isUpvote"] as? NSNumber)?.intValue ?? 1) == 1
        } else {
            let vote = ProjectVote(
                id: uuid,
                ideaId: record["ideaId"] as? String ?? "",
                memberName: record["memberName"] as? String ?? "",
                isUpvote: ((record["isUpvote"] as? NSNumber)?.intValue ?? 1) == 1
            )
            context.insert(vote)
        }
    }

    // MARK: - Fetch Notifications

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
        } catch {
            print("[CloudKit] Apple User ID lookup failed: \(error.localizedDescription)")
        }
        return nil
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

    // MARK: - Subscriptions

    func setupSubscriptions(familyCode: String, appleUserID: String = "", role: String = "") async {
        guard !familyCode.isEmpty else { return }

        if familyZoneID != nil {
            await createDatabaseSubscription()
        } else {
            await createSubscription(
                id: "task-changes-\(familyCode)",
                recordType: "TaskRecord",
                familyCode: familyCode
            )
            await createSubscription(
                id: "shopping-changes-\(familyCode)",
                recordType: "ShoppingRecord",
                familyCode: familyCode
            )
        }

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
    }

    private func createSubscription(id: String, recordType: String, familyCode: String) async {
        do {
            _ = try await database.subscription(for: id)
            return
        } catch {
            print("[CloudKit] Subscription \(id) not found, creating new one")
        }

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


    private func createDatabaseSubscription() async {
        let db = familyDatabase
        let subID = isZoneOwner ? "private-db-changes" : "shared-db-changes"

        do {
            _ = try await db.subscription(for: subID)
            return
        } catch {
            print("[CloudKit] Database subscription \(subID) not found, creating new one")
        }

        let sub = CKDatabaseSubscription(subscriptionID: subID)
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        sub.notificationInfo = info

        do {
            try await db.save(sub)
            print("[CloudKit] Database subscription created: \(subID)")
        } catch {
            print("[CloudKit] Database subscription failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Delta Sync

    private final class DeltaSyncCollector: @unchecked Sendable {
        var records: [CKRecord] = []
        var deletedIDs: [(CKRecord.ID, CKRecord.RecordType)] = []
        var token: CKServerChangeToken?
        var error: Error?
    }

    func deltaSyncFamilyZone(context: ModelContext, familyCode: String) async -> SyncResult {
        guard let zoneID = familyZoneID else { return SyncResult() }

        let isInitialSync = loadChangeToken() == nil
        let maxAttempts = 4
        var collector = DeltaSyncCollector()

        for attempt in 0..<maxAttempts {
            collector = DeltaSyncCollector()
            let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration(
                previousServerChangeToken: loadChangeToken()
            )
            let operation = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [zoneID],
                configurationsByRecordZoneID: [zoneID: config]
            )

            operation.recordWasChangedBlock = { _, result in
                if case .success(let record) = result {
                    collector.records.append(record)
                }
            }

            operation.recordWithIDWasDeletedBlock = { recordID, recordType in
                collector.deletedIDs.append((recordID, recordType))
            }

            operation.recordZoneFetchResultBlock = { _, result in
                switch result {
                case .success((let serverToken, _, _)):
                    collector.token = serverToken
                case .failure(let error):
                    collector.error = error
                }
            }

            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                operation.fetchRecordZoneChangesResultBlock = { _ in
                    continuation.resume()
                }
                familyDatabase.add(operation)
            }

            if let error = collector.error {
                if let ckError = error as? CKError, ckError.code == .changeTokenExpired {
                    clearChangeToken()
                    print("[CloudKit] Change token expired, will do full sync next time")
                    lastSyncError = error.localizedDescription
                    return SyncResult()
                }
                if attempt < maxAttempts - 1 && isTransientCKError(error) {
                    let delay = retryDelay(for: error, attempt: attempt)
                    print("[CloudKit] DELTA SYNC RETRY attempt \(attempt + 1), waiting \(delay)s: \(error.localizedDescription)")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                lastSyncError = error.localizedDescription
                return SyncResult()
            }
            break
        }

        var result = SyncResult()
        var seenTaskIDs = Set<String>()
        var seenRedemptionIDs = Set<String>()
        var seenShoppingIDs = Set<String>()

        for record in collector.records {
            let idStr = record.recordID.recordName
            switch record.recordType {
            case "TaskRecord":
                seenTaskIDs.insert(idStr)
                let taskResult = applyTaskRecord(record, context: context)
                if let newTask = taskResult.newTask {
                    result.newTasks.append(newTask)
                }
                result.changes.append(contentsOf: taskResult.changes)
            case "RedemptionRecord":
                seenRedemptionIDs.insert(idStr)
                let redemptionChanges = applyRedemptionRecord(record, context: context)
                result.changes.append(contentsOf: redemptionChanges)
            case "ShoppingRecord":
                seenShoppingIDs.insert(idStr)
                applyShoppingRecord(record, context: context)
            case "ChatRecord":
                if let change = applyChatRecord(record, context: context) {
                    result.changes.append(change)
                }
            case "ProjectRecord":
                applyProjectRecord(record, context: context)
            case "ProjectIdeaRecord":
                applyIdeaRecord(record, context: context)
            case "ProjectVoteRecord":
                applyVoteRecord(record, context: context)
            case "WishListRecord":
                applyWishListRecord(record, context: context)
            default:
                break
            }
        }

        for (recordID, recordType) in collector.deletedIDs {
            applyDeletion(recordID: recordID, recordType: recordType, context: context)
        }

        if isInitialSync && !collector.records.isEmpty {
            cleanupOrphans(context: context, taskIDs: seenTaskIDs, redemptionIDs: seenRedemptionIDs, shoppingIDs: seenShoppingIDs)
        }

        if let token = collector.token {
            saveChangeToken(token)
        }

        print("[CloudKit] Delta sync: \(collector.records.count) changed, \(collector.deletedIDs.count) deleted, \(result.changes.count) notifications")
        try? context.save()
        return result
    }

    struct TaskSyncResult {
        var newTask: SyncedTask?
        var changes: [SyncChange] = []
    }

    private func applyTaskRecord(_ record: CKRecord, context: ModelContext) -> TaskSyncResult {
        let idStr = record.recordID.recordName
        guard let uuid = UUID(uuidString: idStr) else { return TaskSyncResult() }

        let descriptor = FetchDescriptor<Item>()
        let allTasks = (try? context.fetch(descriptor)) ?? []
        var changes: [SyncChange] = []

        if let local = allTasks.first(where: { $0.id == uuid }) {
            let oldStatus = local.status
            let oldRemindedAt = local.lastRemindedAt
            let newStatus = record["status"] as? String ?? local.status
            let taskName = record["name"] as? String ?? local.name
            let assignedTo = record["assignedTo"] as? String ?? local.assignedTo
            let reward = (record["reward"] as? NSNumber)?.doubleValue ?? local.reward
            let giftText = record["giftText"] as? String ?? local.giftText
            let remoteRemindedAt = record["lastRemindedAt"] as? Date

            local.name = taskName
            local.targetDate = record["targetDate"] as? Date ?? local.targetDate
            local.assignedTo = assignedTo
            local.reward = reward
            local.status = newStatus
            local.createdByChild = ((record["createdByChild"] as? NSNumber)?.intValue ?? 0) == 1
            let deltaArchived = ((record["isArchived"] as? NSNumber)?.intValue ?? 0) == 1
            local.isArchived = newStatus == "missed" ? false : deltaArchived
            local.isRecurring = ((record["isRecurring"] as? NSNumber)?.intValue ?? 0) == 1
            local.giftText = giftText
            local.giftRevealed = ((record["giftRevealed"] as? NSNumber)?.intValue ?? 0) == 1
            let remoteCreatedBy = record["createdBy"] as? String ?? ""
            if !remoteCreatedBy.isEmpty { local.createdBy = remoteCreatedBy }
            let remoteCreatedByID = record["createdByID"] as? String ?? ""
            if !remoteCreatedByID.isEmpty { local.createdByID = remoteCreatedByID }
            if let rr = remoteRemindedAt { local.lastRemindedAt = rr }
            let deltaTransport = record["transportType"] as? String ?? ""
            if !deltaTransport.isEmpty { local.transportType = deltaTransport }
            let deltaProjectId = record["projectId"] as? String ?? ""
            if !deltaProjectId.isEmpty { local.projectId = deltaProjectId }

            if oldStatus != newStatus {
                if newStatus == "approved" {
                    changes.append(.taskApproved(taskName: taskName, assignedTo: assignedTo, reward: reward, hasGift: !giftText.isEmpty))
                } else if newStatus == "inReview" {
                    changes.append(.taskInReview(taskName: taskName, childName: assignedTo))
                } else if newStatus == "open" && oldStatus == "inReview" {
                    changes.append(.taskRejected(taskName: taskName, assignedTo: assignedTo))
                }
            }

            if let rr = remoteRemindedAt, rr != oldRemindedAt, rr.timeIntervalSinceNow > -300 {
                changes.append(.taskReminded(taskName: taskName, assignedTo: assignedTo))
            }

            return TaskSyncResult(changes: changes)
        }

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
            createdByID: record["createdByID"] as? String ?? "",
            transportType: record["transportType"] as? String ?? "none",
            projectId: record["projectId"] as? String ?? ""
        )
        item.isArchived = status == "missed" ? false : ((record["isArchived"] as? NSNumber)?.intValue ?? 0) == 1
        item.giftRevealed = ((record["giftRevealed"] as? NSNumber)?.intValue ?? 0) == 1
        item.lastRemindedAt = record["lastRemindedAt"] as? Date
        context.insert(item)

        var result = TaskSyncResult()
        let createdBy = record["createdBy"] as? String ?? ""
        if status == "open" && !assignedTo.isEmpty {
            result.newTask = SyncedTask(id: uuid, name: name, targetDate: targetDate, assignedTo: assignedTo, createdBy: createdBy)
            result.changes.append(.taskAssigned(taskName: name, assignedTo: assignedTo, createdBy: createdBy))
        }
        return result
    }

    private func applyRedemptionRecord(_ record: CKRecord, context: ModelContext) -> [SyncChange] {
        let idStr = record.recordID.recordName
        guard let uuid = UUID(uuidString: idStr) else { return [] }

        let descriptor = FetchDescriptor<RewardRedemption>()
        let all = (try? context.fetch(descriptor)) ?? []
        var changes: [SyncChange] = []

        if let existing = all.first(where: { $0.id == uuid }) {
            let oldStatus = existing.status
            let newStatus = record["status"] as? String ?? existing.status
            let childName = record["childName"] as? String ?? existing.childName
            let desc = record["itemDescription"] as? String ?? existing.itemDescription
            let coins = (record["coinAmount"] as? NSNumber)?.intValue ?? existing.coinAmount
            let reason = record["rejectReason"] as? String ?? ""

            existing.childName = childName
            existing.coinAmount = coins
            existing.redemptionType = record["redemptionType"] as? String ?? existing.redemptionType
            existing.itemDescription = desc
            existing.status = newStatus
            existing.rejectReason = reason
            existing.createdAt = record["createdAt"] as? Date ?? existing.createdAt
            existing.resolvedAt = record["resolvedAt"] as? Date

            if oldStatus != newStatus {
                switch newStatus {
                case "approved":
                    changes.append(.redemptionApproved(description: desc, childName: childName))
                case "rejected":
                    changes.append(.redemptionRejected(description: desc, childName: childName, reason: reason))
                case "fulfilled":
                    changes.append(.redemptionFulfilled(description: desc, childName: childName))
                default: break
                }
            }
        } else {
            let childName = record["childName"] as? String ?? ""
            let coins = (record["coinAmount"] as? NSNumber)?.intValue ?? 0
            let desc = record["itemDescription"] as? String ?? ""
            let status = record["status"] as? String ?? "pending"

            let r = RewardRedemption(
                id: uuid,
                childName: childName,
                coinAmount: coins,
                redemptionType: record["redemptionType"] as? String ?? "other",
                itemDescription: desc,
                status: status
            )
            r.rejectReason = record["rejectReason"] as? String ?? ""
            r.createdAt = record["createdAt"] as? Date ?? Date()
            r.resolvedAt = record["resolvedAt"] as? Date
            context.insert(r)

            if status == "pending" {
                changes.append(.redemptionRequested(description: desc, childName: childName, coins: coins))
            }
        }
        return changes
    }

    private func applyShoppingRecord(_ record: CKRecord, context: ModelContext) {
        let idStr = record.recordID.recordName
        guard let uuid = UUID(uuidString: idStr) else { return }

        let descriptor = FetchDescriptor<ShoppingItem>()
        let all = (try? context.fetch(descriptor)) ?? []

        let bought = record["isBought"]
        let isBoughtVal: Bool
        if let num = bought as? NSNumber { isBoughtVal = num.intValue == 1 }
        else if let int = bought as? Int { isBoughtVal = int == 1 }
        else { isBoughtVal = false }

        if let existing = all.first(where: { $0.id == uuid }) {
            existing.name = record["name"] as? String ?? existing.name
            existing.addedBy = record["addedBy"] as? String ?? existing.addedBy
            existing.isBought = isBoughtVal
            existing.createdAt = record["createdAt"] as? Date ?? existing.createdAt
        } else {
            let item = ShoppingItem(
                id: uuid,
                name: record["name"] as? String ?? "",
                addedBy: record["addedBy"] as? String ?? "",
                isBought: isBoughtVal,
                createdAt: record["createdAt"] as? Date ?? Date()
            )
            context.insert(item)
        }
    }

    private func applyDeletion(recordID: CKRecord.ID, recordType: CKRecord.RecordType, context: ModelContext) {
        let idStr = recordID.recordName
        guard let uuid = UUID(uuidString: idStr) else { return }

        switch recordType {
        case "TaskRecord":
            let d = FetchDescriptor<Item>()
            if let task = (try? context.fetch(d))?.first(where: { $0.id == uuid }) {
                context.delete(task)
            }
        case "ShoppingRecord":
            let d = FetchDescriptor<ShoppingItem>()
            if let item = (try? context.fetch(d))?.first(where: { $0.id == uuid }) {
                context.delete(item)
            }
        case "RedemptionRecord":
            let d = FetchDescriptor<RewardRedemption>()
            if let r = (try? context.fetch(d))?.first(where: { $0.id == uuid }) {
                context.delete(r)
            }
        case "ChatRecord":
            let d = FetchDescriptor<ChatMessage>()
            if let m = (try? context.fetch(d))?.first(where: { $0.id == uuid }) {
                context.delete(m)
            }
        case "ProjectRecord":
            let d = FetchDescriptor<FamilyProject>()
            if let p = (try? context.fetch(d))?.first(where: { $0.id == uuid }) {
                context.delete(p)
            }
        case "ProjectIdeaRecord":
            let d = FetchDescriptor<ProjectIdea>()
            if let i = (try? context.fetch(d))?.first(where: { $0.id == uuid }) {
                context.delete(i)
            }
        case "ProjectVoteRecord":
            let d = FetchDescriptor<ProjectVote>()
            if let v = (try? context.fetch(d))?.first(where: { $0.id == uuid }) {
                context.delete(v)
            }
        case "WishListRecord":
            let d = FetchDescriptor<WishListItem>()
            if let w = (try? context.fetch(d))?.first(where: { $0.id == uuid }) {
                context.delete(w)
            }
        default:
            break
        }
    }

    private func cleanupOrphans(context: ModelContext, taskIDs: Set<String>, redemptionIDs: Set<String>, shoppingIDs: Set<String>) {
        let tasks = (try? context.fetch(FetchDescriptor<Item>())) ?? []
        for task in tasks where !taskIDs.contains(task.id.uuidString) {
            context.delete(task)
        }
        let redemptions = (try? context.fetch(FetchDescriptor<RewardRedemption>())) ?? []
        for r in redemptions where !redemptionIDs.contains(r.id.uuidString) {
            context.delete(r)
        }
        let shopping = (try? context.fetch(FetchDescriptor<ShoppingItem>())) ?? []
        for s in shopping where !shoppingIDs.contains(s.id.uuidString) {
            context.delete(s)
        }
    }

    // MARK: - Migration (Public → Private Zone)

    func migratePublicToPrivateZone(context: ModelContext, familyCode: String) async {
        guard !familyCode.isEmpty, familyZoneID != nil else { return }
        let key = "hasMigratedToPrivateZone_\(familyCode)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        print("[CloudKit] Starting migration to private zone for \(familyCode)")

        let taskRecords = await fetchAllRecords(type: "TaskRecord", familyCode: familyCode)
        let redemptionRecords = await fetchAllRecords(type: "RedemptionRecord", familyCode: familyCode)
        let shoppingRecords = await fetchAllRecords(type: "ShoppingRecord", familyCode: familyCode)

        var recordsToSave: [CKRecord] = []
        let db = familyDatabase

        for oldRecord in taskRecords {
            let newID = familyRecordID(name: oldRecord.recordID.recordName)
            let newRecord = CKRecord(recordType: "TaskRecord", recordID: newID)
            for key in oldRecord.allKeys() {
                newRecord[key] = oldRecord[key]
            }
            recordsToSave.append(newRecord)
        }

        for oldRecord in redemptionRecords {
            let newID = familyRecordID(name: oldRecord.recordID.recordName)
            let newRecord = CKRecord(recordType: "RedemptionRecord", recordID: newID)
            for key in oldRecord.allKeys() {
                newRecord[key] = oldRecord[key]
            }
            recordsToSave.append(newRecord)
        }

        for oldRecord in shoppingRecords {
            let itemID = oldRecord["itemID"] as? String ?? oldRecord.recordID.recordName
            let newID = familyRecordID(name: itemID)
            let newRecord = CKRecord(recordType: "ShoppingRecord", recordID: newID)
            for key in oldRecord.allKeys() {
                newRecord[key] = oldRecord[key]
            }
            recordsToSave.append(newRecord)
        }

        guard !recordsToSave.isEmpty else {
            UserDefaults.standard.set(true, forKey: key)
            print("[CloudKit] No records to migrate")
            return
        }

        do {
            let batchSize = 400
            for start in stride(from: 0, to: recordsToSave.count, by: batchSize) {
                let end = min(start + batchSize, recordsToSave.count)
                let batch = Array(recordsToSave[start..<end])
                _ = try await db.modifyRecords(saving: batch, deleting: [], savePolicy: .allKeys)
            }
            UserDefaults.standard.set(true, forKey: key)
            print("[CloudKit] Migration complete: \(recordsToSave.count) records copied to private zone (public records kept as fallback)")
        } catch {
            lastSyncError = error.localizedDescription
            print("[CloudKit] Migration failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Re-push Local Data (Recovery)

    func rePushLocalData(context: ModelContext, familyCode: String) async {
        guard !familyCode.isEmpty else { return }

        let tasks = (try? context.fetch(FetchDescriptor<Item>())) ?? []
        for task in tasks {
            await pushTask(task, familyCode: familyCode)
        }

        let redemptions = (try? context.fetch(FetchDescriptor<RewardRedemption>())) ?? []
        for r in redemptions {
            _ = await pushRedemption(r, familyCode: familyCode)
        }

        let shopping = (try? context.fetch(FetchDescriptor<ShoppingItem>())) ?? []
        for item in shopping {
            _ = await pushShoppingItem(item, familyCode: familyCode)
        }

        print("[CloudKit] Re-pushed \(tasks.count) tasks, \(redemptions.count) redemptions, \(shopping.count) shopping items")
    }
}
