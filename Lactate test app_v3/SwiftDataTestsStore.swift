//
//  SwiftDataTestsStore.swift
//  Lactate test app_v3
//
//  Created by Bruno Oliveira on 3/15/26.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class SwiftDataTestsStore: ObservableObject {
    @Published private(set) var tests: [LactateTest] = []

    private var modelContext: ModelContext?

    init() { }

    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
        reload()
    }

    func reload() {
        guard let modelContext else {
            tests = []
            return
        }

        do {
            tests = try MigrationService.loadAllSwiftDataTests(from: modelContext)
        } catch {
            print("Failed to load SwiftData tests: \(error)")
            tests = []
        }
    }

    func appendTest(_ test: LactateTest) {
        guard let modelContext else {
            print("SwiftDataTestsStore is not configured with a ModelContext.")
            return
        }

        let entity = test.makeEntity()
        modelContext.insert(entity)

        do {
            try modelContext.save()
            reload()
        } catch {
            print("Failed to save SwiftData test: \(error)")
        }
    }

    func updateTest(_ updatedTest: LactateTest) {
        guard let modelContext else {
            print("SwiftDataTestsStore is not configured with a ModelContext.")
            return
        }

        do {
            let descriptor = FetchDescriptor<LactateTestEntity>()
            let entities = try modelContext.fetch(descriptor)

            guard let existing = entities.first(where: { $0.id == updatedTest.id }) else {
                print("Could not find SwiftData test to update: \(updatedTest.id)")
                return
            }

            existing.athleteName = updatedTest.athleteName
            existing.sport = updatedTest.sport
            existing.date = updatedTest.date

            for existingStep in existing.steps {
                modelContext.delete(existingStep)
            }

            let replacementSteps = updatedTest.steps
                .sorted { $0.stepIndex < $1.stepIndex }
                .map { step -> LactateStepEntity in
                    let stepEntity = step.makeEntity()
                    stepEntity.test = existing
                    return stepEntity
                }

            existing.steps = replacementSteps

            try modelContext.save()
            reload()
        } catch {
            print("Failed to update SwiftData test: \(error)")
        }
    }

    func updateTest(_ existingTest: LactateTest, with draft: LactateTestDraft) {
        let updatedTest = LactateTest(
            id: existingTest.id,
            athleteName: draft.athleteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Untitled Test"
                : draft.athleteName,
            sport: draft.sport,
            date: draft.date,
            steps: draft.steps
        )

        updateTest(updatedTest)
    }

    func deleteTest(id: UUID) {
        guard let modelContext else {
            print("SwiftDataTestsStore is not configured with a ModelContext.")
            return
        }

        do {
            let descriptor = FetchDescriptor<LactateTestEntity>()
            let entities = try modelContext.fetch(descriptor)

            guard let entity = entities.first(where: { $0.id == id }) else {
                return
            }

            modelContext.delete(entity)
            try modelContext.save()
            reload()
        } catch {
            print("Failed to delete SwiftData test: \(error)")
        }
    }

    func deleteTests(at offsets: IndexSet) {
        let currentTests = tests
        for offset in offsets.sorted(by: >) {
            guard currentTests.indices.contains(offset) else { continue }
            deleteTest(id: currentTests[offset].id)
        }
    }

    func replaceAllTests(with newTests: [LactateTest]) {
        guard let modelContext else {
            print("SwiftDataTestsStore is not configured with a ModelContext.")
            return
        }

        do {
            try MigrationService.clearAllSwiftDataTests(from: modelContext)

            for test in newTests {
                let entity = test.makeEntity()
                modelContext.insert(entity)
            }

            try modelContext.save()
            reload()
        } catch {
            print("Failed to replace all SwiftData tests: \(error)")
        }
    }

    func clearAll() {
        guard let modelContext else {
            print("SwiftDataTestsStore is not configured with a ModelContext.")
            return
        }

        do {
            try MigrationService.clearAllSwiftDataTests(from: modelContext)
            reload()
        } catch {
            print("Failed to clear all SwiftData tests: \(error)")
        }
    }
}
