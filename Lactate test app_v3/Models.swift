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

struct LactateStep: Identifiable, Codable, Hashable {
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

    static func emptyStep(stepIndex: Int = 1) -> LactateStep {
        LactateStep(
            stepIndex: stepIndex,
            lactate: nil,
            avgHeartRate: nil,
            runningPaceSecondsPerKm: nil,
            cyclingSpeedKmh: nil,
            powerWatts: nil
        )
    }
}

struct LactateTest: Identifiable, Codable, Hashable {
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

struct LactateTestDraft {
    var athleteName: String
    var sport: Sport
    var date: Date
    var steps: [LactateStep]

    init(
        athleteName: String = "",
        sport: Sport = .running,
        date: Date = Date(),
        steps: [LactateStep] = [LactateStep.emptyStep(stepIndex: 1)]
    ) {
        self.athleteName = athleteName
        self.sport = sport
        self.date = date
        self.steps = steps
    }

    func asLactateTest() -> LactateTest {
        LactateTest(
            athleteName: athleteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Test" : athleteName,
            sport: sport,
            date: date,
            steps: steps
        )
    }

    mutating func reset() {
        self = LactateTestDraft()
    }
}

final class TestsStore: ObservableObject {
    @Published private(set) var tests: [LactateTest] = []

    private let fileName = "lactate_tests.json"
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

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
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(fileName)
    }

    private func sortTests(_ tests: [LactateTest]) -> [LactateTest] {
        tests.sorted { lhs, rhs in
            if lhs.date != rhs.date {
                return lhs.date > rhs.date
            }
            return lhs.athleteName.localizedCaseInsensitiveCompare(rhs.athleteName) == .orderedAscending
        }
    }

    private func loadTests() {
        let url = fileURL

        guard fileManager.fileExists(atPath: url.path) else {
            tests = []
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try decoder.decode([LactateTest].self, from: data)
            tests = sortTests(decoded)
        } catch {
            print("Failed to load tests: \(error)")
            tests = []
        }
    }

    private func saveTests() {
        do {
            let sorted = sortTests(tests)
            let data = try encoder.encode(sorted)
            try data.write(to: fileURL, options: .atomic)

            if tests != sorted {
                tests = sorted
            }
        } catch {
            print("Failed to save tests: \(error)")
        }
    }

    func reloadFromDisk() {
        loadTests()
    }

    func appendTest(_ test: LactateTest) {
        tests.append(test)
        saveTests()
    }

    func updateTest(_ updatedTest: LactateTest) {
        guard let index = tests.firstIndex(where: { $0.id == updatedTest.id }) else { return }
        tests[index] = updatedTest
        saveTests()
    }

    func deleteTests(at offsets: IndexSet) {
        for offset in offsets.sorted(by: >) {
            tests.remove(at: offset)
        }
        saveTests()
    }

    func deleteTest(id: UUID) {
        tests.removeAll { $0.id == id }
        saveTests()
    }

    func replaceAllTests(with newTests: [LactateTest]) {
        tests = sortTests(newTests)
        saveTests()
    }

    func clearAll() {
        tests = []
        saveTests()
    }
}
