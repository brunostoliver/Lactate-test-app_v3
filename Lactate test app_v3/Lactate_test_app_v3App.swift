//
//  LactateTestApp.swift
//  Lactate test app_v3
//
//  Created by Bruno Oliveira on 3/15/26.
//

import SwiftUI
import SwiftData

@main
struct Lactate_test_app_v3App: App {
    private var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            AthleteEntity.self,
            LactateTestEntity.self,
            LactateStepEntity.self
        ])

        let modelConfiguration = ModelConfiguration(cloudKitDatabase: .automatic)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Failed to create CloudKit-enabled ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}

private struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var swiftDataStore = SwiftDataTestsStore()
    @State private var didSetUpStore = false

    var body: some View {
        AdaptiveRootView(store: swiftDataStore)
            .onAppear {
                guard !didSetUpStore else { return }
                didSetUpStore = true
                setUpSwiftDataStore()
            }
    }

    private func setUpSwiftDataStore() {
        LegacyStorageCleanupService.deleteLegacyJSONFileIfNeeded()
        swiftDataStore.configure(with: modelContext)

        do {
            let swiftDataTests = try MigrationService.loadAllSwiftDataTests(from: modelContext)
            print("SwiftData active store count: \(swiftDataTests.count)")
        } catch {
            print("SwiftData setup failed: \(error)")
        }
    }
}


