//
//  TaskeeWatchApp.swift
//  TaskeeWatch Watch App
//
//  Created by Selva Bhuvanesh on 4/25/26.
//

import SwiftUI
import SwiftData

// MARK: - Watch App Entry Point
// Configures the SwiftData container for the watchOS app using the shared Item model.

@main
struct TaskeeWatchApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Item.self])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
