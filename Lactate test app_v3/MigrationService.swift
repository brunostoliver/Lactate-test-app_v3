//
//  MigrationService.swift
//  Lactate test app_v3
//
//  Created by Bruno Oliveira on 3/15/26.
//

import Foundation
import SwiftData

enum MigrationError: Error {
    case saveFailed
}

struct MigrationService {
    static func importJSONTestsIfNeeded(
        from store: TestsStore,
        into context: ModelContext
    ) throws {
        let descriptor = FetchDescriptor<LactateTestEntity>()
        let existingEntities = try context.fetch(descriptor)

        // If SwiftData already has records, do not import again.
        guard existingEntities.isEmpty else { return }

        let testsToImport = store.tests
        guard !testsToImport.isEmpty else { return }

        for test in testsToImport {
            let entity = test.makeEntity()
            context.insert(entity)
        }

        do {
            try context.save()
        } catch {
            throw MigrationError.saveFailed
        }
    }

    static func clearAllSwiftDataTests(from context: ModelContext) throws {
        let descriptor = FetchDescriptor<LactateTestEntity>()
        let entities = try context.fetch(descriptor)

        for entity in entities {
            context.delete(entity)
        }

        try context.save()
    }

    static func loadAllSwiftDataTests(from context: ModelContext) throws -> [LactateTest] {
        let descriptor = FetchDescriptor<LactateTestEntity>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        let entities = try context.fetch(descriptor)
        return entities.map { LactateTest(entity: $0) }
    }
}
