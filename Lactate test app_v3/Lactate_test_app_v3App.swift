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

        let modelConfiguration = ModelConfiguration(
            cloudKitDatabase: .private("iCloud.PRhealthier.LactateApp")
        )

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
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var swiftDataStore = SwiftDataTestsStore()
    @State private var didSetUpStore = false

    var body: some View {
        AdaptiveRootView(store: swiftDataStore)
            .onAppear {
                guard !didSetUpStore else { return }
                didSetUpStore = true
                setUpSwiftDataStore()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active, didSetUpStore else { return }
                print("Scene became active. Reloading SwiftData store.")
                swiftDataStore.reload()
            }
    }

    private func setUpSwiftDataStore() {
        LegacyStorageCleanupService.deleteLegacyJSONFileIfNeeded()
        swiftDataStore.configure(with: modelContext)

        do {
            print("CloudKit-backed SwiftData container initialized.")
            let swiftDataTests = try MigrationService.loadAllSwiftDataTests(from: modelContext)
            let swiftDataAthletes = try MigrationService.loadAllSwiftDataAthletes(from: modelContext)
            print("SwiftData active athlete count: \(swiftDataAthletes.count)")
            print("SwiftData active store count: \(swiftDataTests.count)")
        } catch {
            print("SwiftData setup failed: \(error)")
        }
    }
}


