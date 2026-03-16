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
    @StateObject private var swiftDataStore = SwiftDataTestsStore()
    @State private var didSetUpStore = false

    var body: some View {
        ContentView(store: swiftDataStore)
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
