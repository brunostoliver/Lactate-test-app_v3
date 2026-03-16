//
//  Lactate_test_app_v3App.swift
//  Lactate test app_v3
//
//  Created by Bruno Oliveira on 3/15/26.
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
    @StateObject private var store = TestsStore()
    @State private var didAttemptMigration = false

    var body: some View {
        ContentView()
            .onAppear {
                guard !didAttemptMigration else { return }
                didAttemptMigration = true

                runMigrationVerification()
            }
    }

    private func runMigrationVerification() {
        do {
            try MigrationService.importJSONTestsIfNeeded(
                from: store,
                into: modelContext
            )

            let swiftDataTests = try MigrationService.loadAllSwiftDataTests(from: modelContext)

            print("JSON tests available: \(store.tests.count)")
            print("SwiftData tests available: \(swiftDataTests.count)")

            for test in swiftDataTests {
                print("SwiftData test: \(test.athleteName) | \(test.date) | steps: \(test.steps.count)")
            }
        } catch {
            print("SwiftData migration or verification failed: \(error)")
        }
    }
}
