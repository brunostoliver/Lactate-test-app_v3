//
//  Models.swift
//  Lactate test app_v3
//
//  Created by Bruno Oliveira on 3/15/26.
//

import Foundation
import Combine

enum Sport: String, CaseIterable, Identifiable, Codable {
    case running
    case cycling

    var id: String { rawValue }
}

struct LactateStep: Identifiable, Codable {
    let id: UUID
    var stepIndex: Int
    var lactate: Double?
    var avgHeartRate: Int?
    var runningPaceSecondsPerKm: Int?
    var cyclingSpeedKmh: Double?
    var powerWatts: Int?

    init(
        id: UUID = UUID(),
        stepIndex: Int,
        lactate: Double?,
        avgHeartRate: Int?,
        runningPaceSecondsPerKm: Int?,
        cyclingSpeedKmh: Double?,
        powerWatts: Int?
    ) {
        self.id = id
        self.stepIndex = stepIndex
        self.lactate = lactate
        self.avgHeartRate = avgHeartRate
        self.runningPaceSecondsPerKm = runningPaceSecondsPerKm
        self.cyclingSpeedKmh = cyclingSpeedKmh
        self.powerWatts = powerWatts
    }
}

struct LactateTest: Identifiable, Codable {
    let id: UUID
    var athleteName: String
    var sport: Sport
    var date: Date
    var steps: [LactateStep]

    init(
        id: UUID = UUID(),
        athleteName: String,
        sport: Sport,
        date: Date,
        steps: [LactateStep]
    ) {
        self.id = id
        self.athleteName = athleteName
        self.sport = sport
        self.date = date
        self.steps = steps
    }
}

final class TestsStore: ObservableObject {
    @Published var tests: [LactateTest] = [] {
        didSet {
            saveTests()
        }
    }

    private let fileName = "lactate_tests.json"
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        loadTests()
    }

    private var fileURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(fileName)
    }

    private func loadTests() {
        let url = fileURL

        guard FileManager.default.fileExists(atPath: url.path) else {
            tests = []
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try decoder.decode([LactateTest].self, from: data)
            tests = decoded.sorted { $0.date > $1.date }
        } catch {
            print("Failed to load tests: \(error)")
            tests = []
        }
    }

    private func saveTests() {
        do {
            let data = try encoder.encode(tests)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save tests: \(error)")
        }
    }

    func reloadFromDisk() {
        loadTests()
    }

    func deleteTests(at offsets: IndexSet) {
        for offset in offsets.sorted(by: >) {
            tests.remove(at: offset)
        }
    }

    func deleteTest(id: UUID) {
        tests.removeAll { $0.id == id }
    }

    func replaceAllTests(with newTests: [LactateTest]) {
        tests = newTests.sorted { $0.date > $1.date }
    }

    func appendTest(_ test: LactateTest) {
        tests.append(test)
        tests.sort { $0.date > $1.date }
    }

    func clearAll() {
        tests = []
    }
}
