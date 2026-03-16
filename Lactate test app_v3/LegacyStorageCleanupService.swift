//
//  LegacyStorageCleanupService.swift
//  Lactate test app_v3
//
//  Created by Bruno Oliveira on 3/15/26.
//

import Foundation

struct LegacyStorageCleanupService {
    private static let fileName = "lactate_tests.json"
    private static let cleanupFlagKey = "didDeleteLegacyJSONFile"

    static func deleteLegacyJSONFileIfNeeded() {
        let defaults = UserDefaults.standard

        guard !defaults.bool(forKey: cleanupFlagKey) else { return }

        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let fileURL = documentsDirectory.appendingPathComponent(fileName)

        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                try fileManager.removeItem(at: fileURL)
                print("Deleted legacy JSON file: \(fileURL.lastPathComponent)")
            } catch {
                print("Failed to delete legacy JSON file: \(error)")
                return
            }
        }

        defaults.set(true, forKey: cleanupFlagKey)
    }
}
