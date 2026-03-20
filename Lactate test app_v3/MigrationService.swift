//
//  MigrationService.swift
//  Lactate test app_v3
//
//  Created by Bruno Oliveira on 3/15/26.
//

import Foundation
import SwiftData

struct MigrationService {
    static let untitledAthleteName = "Untitled Athlete"

    static func normalizedAthleteName(_ rawName: String) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? untitledAthleteName : trimmed
    }

    static func loadAllSwiftDataAthletes(from context: ModelContext) throws -> [Athlete] {
        try ensureAthleteRelationships(in: context)

        let descriptor = FetchDescriptor<AthleteEntity>()
        let entities = try context.fetch(descriptor)
        return entities
            .sorted {
                if $0.name == $1.name {
                    return $0.createdAt < $1.createdAt
                }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            .map { Athlete(entity: $0) }
    }

    static func clearAllSwiftDataTests(from context: ModelContext) throws {
        let descriptor = FetchDescriptor<AthleteEntity>()
        let entities = try context.fetch(descriptor)

        for entity in entities {
            context.delete(entity)
        }

        try context.save()
    }

    static func loadAllSwiftDataTests(from context: ModelContext) throws -> [LactateTest] {
        try ensureAthleteRelationships(in: context)

        let descriptor = FetchDescriptor<LactateTestEntity>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        let entities = try context.fetch(descriptor)
        return entities.map { LactateTest(entity: $0) }
    }

    @discardableResult
    static func ensureAthleteRelationships(in context: ModelContext) throws -> [AthleteEntity] {
        let athleteDescriptor = FetchDescriptor<AthleteEntity>()
        let testDescriptor = FetchDescriptor<LactateTestEntity>()

        let athletes = try context.fetch(athleteDescriptor)
        let tests = try context.fetch(testDescriptor)

        var athletesByName: [String: AthleteEntity] = [:]
        for athlete in athletes {
            let normalized = normalizedAthleteName(athlete.name)
            athlete.name = normalized
            athletesByName[normalized] = athlete
        }

        var didChange = false

        for test in tests {
            let normalizedName = normalizedAthleteName(test.athleteName)
            if test.athleteName != normalizedName {
                test.athleteName = normalizedName
                didChange = true
            }

            let athlete = athletesByName[normalizedName] ?? {
                let newAthlete = AthleteEntity(name: normalizedName)
                context.insert(newAthlete)
                athletesByName[normalizedName] = newAthlete
                didChange = true
                return newAthlete
            }()

            if test.athlete?.id != athlete.id {
                test.athlete = athlete
                didChange = true
            }
        }

        if didChange {
            try context.save()
        }

        return athletesByName.values.sorted {
            if $0.name == $1.name {
                return $0.createdAt < $1.createdAt
            }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
}


