//
//  TaskeeApp.swift
//  Taskee
//
//  Created by Selva Bhuvanesh on 4/25/26.
//

import SwiftUI
import SwiftData

@main
struct TaskeeApp: App {
    @State private var authManager = AuthManager()
    @State private var notificationManager = NotificationManager()
    @State private var showOnboarding = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            FamilyMember.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            if let appSupport = urls.first {
                let storeURL = appSupport.appendingPathComponent("default.store")
                try? FileManager.default.removeItem(at: storeURL)
                try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
                try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
            }
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if !authManager.isLoggedIn {
                    LoginView()
                } else if authManager.role.isEmpty {
                    RoleSelectionView()
                } else if authManager.role == "parent" {
                    ContentView()
                } else {
                    ChildDashboardView()
                }
            }
            .environment(authManager)
            .environment(notificationManager)
            .onAppear {
                notificationManager.requestPermission()
            }
            .sheet(isPresented: $showOnboarding) {
                ParentOnboardingView {
                    authManager.hasCompletedOnboarding = true
                    showOnboarding = false
                }
                .environment(authManager)
                .environment(notificationManager)
            }
            .onChange(of: authManager.role) { _, newRole in
                if newRole == "parent" && !authManager.hasCompletedOnboarding {
                    showOnboarding = true
                }
            }
            .onAppear {
                if authManager.isLoggedIn && authManager.role == "parent" && !authManager.hasCompletedOnboarding {
                    showOnboarding = true
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
