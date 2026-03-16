//
//  MigrationService.swift
//  Lactate test app_v3
//
//  Created by Bruno Oliveira on 3/15/26.
//

import Foundation
import SwiftData

struct MigrationService {
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
