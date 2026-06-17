import Foundation
import EventKit
import SwiftUI

@Observable
final class CalendarManager {

    // MARK: - UserDefaults Keys
    private static let isEnabledKey = "calendarSyncEnabled"
    private static let hasSeenPromptKey = "hasSeenCalendarPrompt"
    private static let enabledCalendarIDsKey = "enabledCalendarIDs"

    // MARK: - State
    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.isEnabledKey)
            if isEnabled && authorizationStatus == .fullAccess {
                loadCalendars()
                if enabledCalendarIDs.isEmpty {
                    enabledCalendarIDs = Set(availableCalendars.map { $0.calendarIdentifier })
                }
            } else if !isEnabled {
                events = []
                listEvents = []
            }
        }
    }

    var hasSeenPrompt: Bool {
        didSet { UserDefaults.standard.set(hasSeenPrompt, forKey: Self.hasSeenPromptKey) }
    }

    var authorizationStatus: EKAuthorizationStatus = .notDetermined
    var availableCalendars: [EKCalendar] = []
    var events: [EKEvent] = []
    var listEvents: [EKEvent] = []

    private let eventStore = EKEventStore()
    private var lastFetchedDate: Date?

    // MARK: - Enabled Calendar IDs (persisted)
    private var enabledCalendarIDs: Set<String> {
        get {
            let stored = UserDefaults.standard.stringArray(forKey: Self.enabledCalendarIDsKey) ?? []
            return Set(stored)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: Self.enabledCalendarIDsKey)
        }
    }

    // MARK: - Init
    init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: Self.isEnabledKey)
        self.hasSeenPrompt = UserDefaults.standard.bool(forKey: Self.hasSeenPromptKey)
        self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)

        if authorizationStatus == .fullAccess && isEnabled {
            loadCalendars()
            fetchListEvents()
        }
    }

    // MARK: - Request Access
    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            await MainActor.run {
                authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                if granted {
                    isEnabled = true
                    loadCalendars()
                    if enabledCalendarIDs.isEmpty {
                        enabledCalendarIDs = Set(availableCalendars.map { $0.calendarIdentifier })
                    }
                }
            }
            return granted
        } catch {
            await MainActor.run {
                authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            }
            return false
        }
    }

    // MARK: - Calendar List
    func loadCalendars() {
        availableCalendars = eventStore.calendars(for: .event)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func isCalendarEnabled(_ calendar: EKCalendar) -> Bool {
        enabledCalendarIDs.contains(calendar.calendarIdentifier)
    }

    func toggleCalendar(_ calendar: EKCalendar) {
        let id = calendar.calendarIdentifier
        if enabledCalendarIDs.contains(id) {
            enabledCalendarIDs.remove(id)
        } else {
            enabledCalendarIDs.insert(id)
        }
        if let date = lastFetchedDate {
            fetchEvents(for: date)
        }
        fetchListEvents()
    }

    // MARK: - Fetch Events for a Day
    func fetchEvents(for date: Date) {
        guard isEnabled, authorizationStatus == .fullAccess else {
            events = []
            return
        }
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        guard let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) else {
            events = []
            return
        }

        let enabledCals = availableCalendars.filter { enabledCalendarIDs.contains($0.calendarIdentifier) }
        guard !enabledCals.isEmpty else {
            events = []
            return
        }

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: enabledCals)
        lastFetchedDate = date
        events = eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Fetch Events for List View (wider range)
    func fetchListEvents() {
        guard isEnabled, authorizationStatus == .fullAccess else {
            listEvents = []
            return
        }
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -7, to: cal.startOfDay(for: Date()))!
        let end = cal.date(byAdding: .day, value: 31, to: cal.startOfDay(for: Date()))!

        let enabledCals = availableCalendars.filter { enabledCalendarIDs.contains($0.calendarIdentifier) }
        guard !enabledCals.isEmpty else {
            listEvents = []
            return
        }

        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: enabledCals)
        listEvents = eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    }

    func listEventsForDate(_ date: Date) -> [EKEvent] {
        let cal = Calendar.current
        return listEvents.filter { cal.isDate($0.startDate, inSameDayAs: date) }
    }

    // MARK: - Event Count for a Date
    func eventCount(for date: Date) -> Int {
        guard isEnabled, authorizationStatus == .fullAccess else { return 0 }
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        guard let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) else { return 0 }

        let enabledCals = availableCalendars.filter { enabledCalendarIDs.contains($0.calendarIdentifier) }
        guard !enabledCals.isEmpty else { return 0 }

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: enabledCals)
        return eventStore.events(matching: predicate).count
    }

    // MARK: - Color Helper
    static func color(for calendar: EKCalendar) -> Color {
        Color(cgColor: calendar.cgColor)
    }
}
