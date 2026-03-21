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
    @Published private(set) var athletes: [Athlete] = []
    @Published private(set) var tests: [LactateTest] = []

    private var modelContext: ModelContext?

    init() { }

    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
        reload()
    }

    func reload() {
        guard let modelContext else {
            athletes = []
            tests = []
            return
        }

        do {
            athletes = try MigrationService.loadAllSwiftDataAthletes(from: modelContext)
            tests = try MigrationService.loadAllSwiftDataTests(from: modelContext)
        } catch {
            print("Failed to load SwiftData store: \(error)")
            athletes = []
            tests = []
        }
    }

    func appendTest(_ test: LactateTest) {
        guard let modelContext else {
            print("SwiftDataTestsStore is not configured with a ModelContext.")
            return
        }

        do {
            let athlete = try athleteEntity(
                forName: test.athleteName,
                athleteID: test.athleteID,
                in: modelContext
            )

            let entity = test.makeEntity()
            entity.athleteName = athlete.name
            entity.athlete = athlete
            modelContext.insert(entity)

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

            let athlete = try athleteEntity(
                forName: updatedTest.athleteName,
                athleteID: updatedTest.athleteID,
                in: modelContext
            )

            existing.athleteName = athlete.name
            existing.testName = updatedTest.resolvedTestName
            existing.restingLactate = updatedTest.restingLactate
            existing.temperatureCelsius = updatedTest.temperatureCelsius
            existing.temperatureUnit = updatedTest.temperatureUnit
            existing.humidityPercent = updatedTest.humidityPercent
            existing.terrain = updatedTest.terrain
            existing.notes = updatedTest.notes
            existing.athlete = athlete
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
            athleteID: existingTest.athleteID,
            athleteName: draft.athleteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Untitled Athlete"
                : draft.athleteName,
            testName: draft.resolvedTestName,
            restingLactate: draft.restingLactate,
            temperatureCelsius: draft.temperatureCelsius,
            temperatureUnit: draft.temperatureUnit,
            humidityPercent: draft.humidityPercent,
            terrain: draft.terrain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : draft.terrain.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: draft.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : draft.notes.trimmingCharacters(in: .whitespacesAndNewlines),
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

    func tests(for athleteID: UUID) -> [LactateTest] {
        tests
            .filter { $0.athleteID == athleteID }
            .sorted { lhs, rhs in
                if lhs.date == rhs.date {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.date > rhs.date
            }
    }

    @discardableResult
    func appendAthlete(name: String) -> Athlete? {
        appendAthlete(name: name, dateOfBirth: nil, gender: nil)
    }

    @discardableResult
    func appendAthlete(name: String, dateOfBirth: Date?, gender: AthleteGender?) -> Athlete? {
        guard let modelContext else {
            print("SwiftDataTestsStore is not configured with a ModelContext.")
            return nil
        }

        let normalizedName = MigrationService.normalizedAthleteName(name)

        do {
            let descriptor = FetchDescriptor<AthleteEntity>()
            let entities = try modelContext.fetch(descriptor)

            if let existing = entities.first(where: { $0.name.localizedCaseInsensitiveCompare(normalizedName) == .orderedSame }) {
                existing.dateOfBirth = dateOfBirth
                existing.gender = gender
                try modelContext.save()
                reload()
                return Athlete(entity: existing)
            }

            let athlete = AthleteEntity(
                name: normalizedName,
                dateOfBirth: dateOfBirth,
                genderRawValue: gender?.rawValue
            )
            modelContext.insert(athlete)
            try modelContext.save()
            reload()
            return Athlete(entity: athlete)
        } catch {
            print("Failed to save athlete: \(error)")
            return nil
        }
    }

    func updateAthlete(
        id: UUID,
        name: String,
        dateOfBirth: Date?,
        gender: AthleteGender?
    ) {
        guard let modelContext else {
            print("SwiftDataTestsStore is not configured with a ModelContext.")
            return
        }

        let normalizedName = MigrationService.normalizedAthleteName(name)

        do {
            let descriptor = FetchDescriptor<AthleteEntity>()
            let athletes = try modelContext.fetch(descriptor)

            guard let athlete = athletes.first(where: { $0.id == id }) else {
                return
            }

            athlete.name = normalizedName
            athlete.dateOfBirth = dateOfBirth
            athlete.gender = gender

            for test in athlete.tests {
                test.athleteName = normalizedName
            }

            try modelContext.save()
            reload()
        } catch {
            print("Failed to update athlete: \(error)")
        }
    }

    func deleteAthlete(id: UUID) {
        guard let modelContext else {
            print("SwiftDataTestsStore is not configured with a ModelContext.")
            return
        }

        do {
            let descriptor = FetchDescriptor<AthleteEntity>()
            let athletes = try modelContext.fetch(descriptor)

            guard let athlete = athletes.first(where: { $0.id == id }) else {
                return
            }

            modelContext.delete(athlete)
            try modelContext.save()
            reload()
        } catch {
            print("Failed to delete athlete: \(error)")
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
                let athlete = try athleteEntity(
                    forName: test.athleteName,
                    athleteID: test.athleteID,
                    in: modelContext
                )

                let entity = test.makeEntity()
                entity.athleteName = athlete.name
                entity.athlete = athlete
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

    private func athleteEntity(
        forName rawName: String,
        athleteID: UUID?,
        in context: ModelContext
    ) throws -> AthleteEntity {
        let normalizedName = MigrationService.normalizedAthleteName(rawName)
        let descriptor = FetchDescriptor<AthleteEntity>()
        let athletes = try context.fetch(descriptor)

        if let athleteID,
           let existingByID = athletes.first(where: { $0.id == athleteID }) {
            if existingByID.name != normalizedName {
                existingByID.name = normalizedName
            }
            return existingByID
        }

        if let existingByName = athletes.first(where: {
            $0.name.localizedCaseInsensitiveCompare(normalizedName) == .orderedSame
        }) {
            return existingByName
        }

        let athlete = AthleteEntity(name: normalizedName)
        context.insert(athlete)
        return athlete
    }
}


