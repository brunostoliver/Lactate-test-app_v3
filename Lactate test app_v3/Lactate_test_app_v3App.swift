//
//  Lactate_test_app_v3App.swift
//  Lactate test app_v3
//
//  Created by Leonor Oliveira on 3/15/26.
//

import SwiftUI
import SwiftData

@main
struct Lactate_test_app_v3App: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [LactateTestEntity.self, LactateStepEntity.self])
    }
}

private struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    @StateObject private var jsonStore = TestsStore()
    @StateObject private var swiftDataStore = SwiftDataTestsStore()

    @State private var didSetUpStore = false

    private let migrationFlagKey = "didMigrateJSONToSwiftData"

    var body: some View {
        ContentView(store: swiftDataStore)
            .onAppear {
                guard !didSetUpStore else { return }
                didSetUpStore = true
                setUpSwiftDataStore()
            }
    }

    private func setUpSwiftDataStore() {
        swiftDataStore.configure(with: modelContext)

        do {
            let alreadyMigrated = UserDefaults.standard.bool(forKey: migrationFlagKey)

            if !alreadyMigrated {
                try MigrationService.importJSONTestsIfNeeded(
                    from: jsonStore,
                    into: modelContext
                )

                UserDefaults.standard.set(true, forKey: migrationFlagKey)
                print("JSON to SwiftData migration completed.")
            } else {
                print("JSON to SwiftData migration already completed previously.")
            }

            swiftDataStore.reload()

            let swiftDataTests = try MigrationService.loadAllSwiftDataTests(from: modelContext)
            print("SwiftData active store count: \(swiftDataTests.count)")
        } catch {
            print("SwiftData setup failed: \(error)")
        }
    }
}
